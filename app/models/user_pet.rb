# app/models/user_pet.rb

class UserPet < ApplicationRecord
  attr_accessor :skip_default_ability

  belongs_to :user
  belongs_to :pet
  belongs_to :egg
  belongs_to :rarity
  belongs_to :pet_thought, optional: true
  has_and_belongs_to_many :battle_sessions
  has_and_belongs_to_many :user_explorations, join_table: "user_explorations_pets"

  belongs_to :predecessor_user_pet,
             class_name: "UserPet",
             optional: true
  belongs_to :successor_user_pet,
             class_name: "UserPet",
             optional: true

  # Abilities this pet has learned
  has_many :user_pet_abilities, dependent: :destroy
  has_many :learned_abilities,
           through: :user_pet_abilities,
           source: :ability

  scope :equipped, -> { where(equipped: true) }
  scope :active, -> { where(retired_at: nil) }

  belongs_to :held_user_item,
             class_name: "UserItem",
             optional: true

  after_create :assign_default_ability, unless: -> { skip_default_ability }
  before_destroy :destroy_associations
  before_destroy :unlink_evolution_relations

  LEVEL_CAP       = 20
  EXP_PER_LEVEL   = 100
  MAX_ENERGY      = 100
  ENERGY_INTERVAL = 5.minutes
  RARE_CHANCE = 0.5

  LEVELING_STONE_TYPES = %w[
    leveling_stone
    normal_stone
    fire_stone
    water_stone
    electric_stone
    grass_stone
    ice_stone
    shadow_stone
    metal_stone
    wind_stone
    spirit_stone
    storm_stone
    celestial_stone
  ].freeze

  NEEDS_MAX  = 100
  NEEDS_MIN  = 0

  def ability_references
    load_ability_cache!
    @ability_references
  end

  def ability_elements
    load_ability_cache!
    @ability_elements
  end

  HUNGER_DECAY_PER_MIN  = 1.0 / 30   # -1 per 30 minutes
  HYGIENE_DECAY_PER_MIN = 1.0 / 120  # -1 per 2 hours
  BOREDOM_DECAY_PER_MIN = 1.0 / 45   # -1 per 45 minutes
  INJURY_HEAL_PER_MIN   = 1.0 / 90   # +1 per 90 minutes
  MOOD_RECALC_WEIGHT    = 0.5
  GOOD_DAY_THRESHOLD    = 70

  STARVING_THRESHOLD          = 30
  STARVING_RECOVERY_THRESHOLD = 45
  STARVING_TICKS_REQUIRED     = 6
  STARVING_GRACE_LIMIT        = 2

  PERKY_MOOD_THRESHOLD          = 80
  PERKY_ENTERTAINMENT_THRESHOLD = 80
  PERKY_RECOVERY_THRESHOLD      = 65
  PERKY_TICKS_REQUIRED          = 6
  PERKY_GRACE_LIMIT             = 2

  HAPPY_MOOD_THRESHOLD        = 75
  HAPPY_BOREDOM_MIN           = 75
  HAPPY_REQUIRED_TICKS        = 5
  HAPPY_GRACE_LIMIT           = 2
  HAPPY_LOSS_MOOD_THRESHOLD   = 60
  HAPPY_LOSS_BOREDOM_THRESHOLD = 60

  TICKED_OFF_MOOD_THRESHOLD   = 45
  TICKED_OFF_REQUIRED_TICKS   = 4
  TICKED_OFF_RECOVERY_MOOD    = 65
  TICKED_OFF_RECOVERY_STREAK  = 3

  WELL_FED_THRESHOLD          = 85
  WELL_FED_REQUIRED_TICKS     = 4
  WELL_FED_LOSS_THRESHOLD     = 65
  WELL_FED_GRACE_LIMIT        = 2

  BASE_IMPACTS = {
    "play"      => { playfulness: 2.0, affection: 1.0, temperament: 0.0, curiosity: 1.0, confidence: 0.0 },
    "cuddle"    => { playfulness: 0.5, affection: 2.5, temperament: -0.5, curiosity: 0.0, confidence: 1.0 },
    "reprimand" => { playfulness: -1.0, affection: -1.5, temperament: 2.0, curiosity: 0.0, confidence: 0.5 },
    "feed"      => { playfulness: 0.0, affection: 1.5, temperament: 0.0, curiosity: 2.0, confidence: 0.0 },
    "explore"   => { playfulness: 1.0, affection: 0.0, temperament: 0.0, curiosity: 2.5, confidence: 0.5 }
  }.freeze

  # Exceptions for energy logic
  class PetSleepingError < StandardError; end
  class NotEnoughEnergyError < StandardError; end

  # Deduct `amount` from energy after catching up; may set asleep_until.
  def deduct_energy!(amount)
    catch_up_energy!

    if asleep_until.present? && Time.current < asleep_until
      remaining = ((asleep_until - Time.current) / 60).ceil
      raise PetSleepingError, "#{pet.name} is asleep for another #{remaining} minute#{'s' if remaining != 1}."
    end

    raise NotEnoughEnergyError, "#{pet.name} doesn’t have enough energy to interact." unless energy.to_i >= amount

    was_full = energy.to_i >= MAX_ENERGY
    self.energy -= amount
    self.last_energy_update_at = Time.current if was_full
    self.asleep_until = Time.current + sleep_duration if energy <= 10
  end

  # Alternative energy spender (keeps regen timer running)
  def spend_energy!(amount)
    if asleep_until.present? && Time.current < asleep_until
      remaining = ((asleep_until - Time.current) / 60).ceil
      raise PetSleepingError, "#{pet.name} is asleep for another #{remaining} minute#{'s' if remaining != 1}."
    end

    raise NotEnoughEnergyError, "#{pet.name} doesn’t have enough energy to interact." unless energy.to_i >= amount

    self.last_energy_update_at = Time.current if energy.to_i >= MAX_ENERGY
    self.energy -= amount
    self.asleep_until = Time.current + sleep_duration if energy <= 10
  end

  # Seconds until next energy tick
  def seconds_until_next_energy
    last    = last_energy_update_at || created_at
    elapsed = Time.current.to_i - last.to_i
    rem     = ENERGY_INTERVAL - (elapsed % ENERGY_INTERVAL)
    rem.zero? ? ENERGY_INTERVAL : rem
  end

  # Grant energy ticks since last update
  def catch_up_energy!
    now            = Time.current
    last           = last_energy_update_at || created_at
    elapsed_secs   = now.to_i - last.to_i
    ticks          = (elapsed_secs / ENERGY_INTERVAL).floor
    return 0 if ticks <= 0

    new_energy     = [energy.to_i + ticks, MAX_ENERGY].min
    leftover_secs  = elapsed_secs - (ticks * ENERGY_INTERVAL)
    update!(
      energy:                new_energy,
      last_energy_update_at: now - leftover_secs
    )

    ticks
  end

  def catch_up_needs!(save: true, care_ticks: nil)
    now = Time.current
    last = needs_updated_at || created_at
    elapsed_seconds = (now - last)
    elapsed_minutes = (elapsed_seconds / 60.0)
    return if elapsed_minutes <= 0.0

    ticks = care_ticks.nil? ? (elapsed_seconds / ENERGY_INTERVAL).floor : care_ticks.to_i

    current_hunger  = hunger.to_i
    current_hygiene = hygiene.to_i
    current_boredom = boredom.to_i
    current_injury  = injury_level.to_i

    new_hunger       = clamp_need(current_hunger - HUNGER_DECAY_PER_MIN * elapsed_minutes)
    new_hygiene      = clamp_need(current_hygiene - HYGIENE_DECAY_PER_MIN * elapsed_minutes)
    new_boredom      = clamp_need(current_boredom - BOREDOM_DECAY_PER_MIN * elapsed_minutes)
    new_injury_level = clamp_need(current_injury + INJURY_HEAL_PER_MIN * elapsed_minutes)

    no_need_changes = new_hunger == current_hunger &&
                      new_hygiene == current_hygiene &&
                      new_boredom == current_boredom &&
                      new_injury_level == current_injury

    return if no_need_changes && ticks <= 0

    # Log if pet was neglected for 12h+ and any need hit clamp
    if elapsed_minutes >= 12 * 60 && ([new_hunger, new_hygiene, new_boredom].any? { |v| v == NEEDS_MIN })
      Rails.logger.info("[NeedsDecay] Pet=#{id} neglected #{(elapsed_minutes/60).round}m; clamped a need to 0")
    end

    self.hunger       = new_hunger
    self.hygiene      = new_hygiene
    self.boredom      = new_boredom
    self.injury_level = new_injury_level
    self.needs_updated_at = now

    recalc_mood!(save: false)
    update_need_flags!(ticks)

    save!(validate: false) if save
  end

  def recalc_mood!(save: true)
    needs_average = (hunger.to_f + hygiene.to_f + boredom.to_f + injury_level.to_f) / 4.0
    personality_stats = [playfulness, affection, curiosity, confidence, temperament].compact
    personality_average = if personality_stats.present?
                            personality_stats.sum.to_f / personality_stats.size
                          else
                            needs_average
                          end

    target_mood = (needs_average * 0.6) + (personality_average * 0.4)
    blended     = (mood.to_f * (1.0 - MOOD_RECALC_WEIGHT)) + (target_mood * MOOD_RECALC_WEIGHT)

    self.mood = clamp_need(blended)
    save!(validate: false) if save
  end

  def good_day_tick!(reference_time: Time.current)
    today = reference_time.to_date
    return unless today
    return if last_good_day.present? && last_good_day >= today

    needs_ok = [hunger, hygiene, boredom, injury_level, mood].all? { |value| value.to_i >= GOOD_DAY_THRESHOLD }
    return unless needs_ok

    self.care_good_days_count += 1
    self.last_good_day = today
    maybe_add_streak_badge

    save!(validate: false)
  end

  # Duration to sleep when energy falls to 10 or below
  def sleep_duration
    base      = 2.hours
    reduction = (playfulness.to_i * 10).minutes
    [base - reduction, 30.minutes].max
  end

  def can_interact?
    return false if retired?
    interactions_remaining.to_i.positive?
  end

  def can_level_up?
    return false if retired?
    exp.to_i >= EXP_PER_LEVEL && level.to_i < LEVEL_CAP
  end

  def level_up!
    return unless can_level_up?

    self.exp                      = exp.to_i - EXP_PER_LEVEL
    self.level                    = level.to_i + 1
    self.interactions_remaining   = 5
    self.pet_thought              = PetThought.order("RANDOM()").first
    save!
  end

  def apply_interaction(interaction_type)
    return unless pet_thought && BASE_IMPACTS.key?(interaction_type)

    base    = BASE_IMPACTS[interaction_type]
    thought = pet_thought

    deltas = {
      playfulness:  base[:playfulness] * thought.playfulness_mod,
      affection:    base[:affection]   * thought.affection_mod,
      temperament:  base[:temperament] * thought.temperament_mod,
      curiosity:    base[:curiosity]   * thought.curiosity_mod,
      confidence:   base[:confidence]  * thought.confidence_mod
    }

    deltas.each { |stat, change| write_attribute(stat, (send(stat) || 0) + change) }
    self.interactions_remaining -= 1
    save!
  end

  # How much Glow Essence the player receives for releasing this pet.
  def glow_essence_reward
    rarity_multiplier = rarity.glow_essence_multiplier.to_i
    current_level     = [level.to_i, 1].max
    current_level * rarity_multiplier
  end

  def exploring?
    user_explorations.where(completed_at: nil).exists?
  end

  def set_flag!(key, value)
    flags = state_flags.deep_dup
    str_key = key.to_s
    if value.nil?
      flags.delete(str_key)
    else
      flags[str_key] = value
    end
    update_columns(state_flags: flags, updated_at: Time.current)
  end

  def flag?(key)
    state_flags[key.to_s].present?
  end

  def state_flags
    super || {}
  end

  def evolution_journal
    super || {}
  end

  def badges
    super || []
  end

  def retired?
    retired_at.present?
  end

  def self.leveling_stone_types
    LEVELING_STONE_TYPES
  end

  def track_exploration_progress!(world, flag_rules = {})
    flags = state_flags.deep_dup
    rules_hash = flag_rules.is_a?(Hash) ? flag_rules : {}

    rules_hash.each do |flag_name, rule|
      rule = rule || {}
      case rule['type'] || 'counter'
      when 'counter'
        counter_key = (rule['counter_key'] || "#{flag_name}_count").to_s
        increment    = rule['increment'].to_i
        increment    = 1 if increment.zero?
        threshold    = rule['threshold'].to_i

        current = flags.fetch(counter_key, 0).to_i + increment
        flags[counter_key] = current
        flags[flag_name.to_s] = true if threshold.positive? && current >= threshold
      when 'set'
        flags[flag_name.to_s] = rule['value']
      when 'toggle'
        key = flag_name.to_s
        flags[key] = !flags[key]
      end
    end

    self.state_flags = flags if flags != state_flags
  end

  private

  def clamp_need(value)
    val = value.to_f
    val = NEEDS_MAX if val > NEEDS_MAX
    val = NEEDS_MIN if val < NEEDS_MIN
    val.round
  end

  def maybe_add_streak_badge
    milestones = {
      7  => "care_streak_7",
      14 => "care_streak_14",
      30 => "care_streak_30"
    }
    badge_key = milestones[care_good_days_count]
    return unless badge_key

    unless badges.include?(badge_key)
      self.badges = badges + [badge_key]
    end
  end

  def destroy_associations
    battle_sessions.clear
  end

  def unlink_evolution_relations
    if predecessor_user_pet_id.present?
      UserPet.where(id: predecessor_user_pet_id).update_all(successor_user_pet_id: nil)
    end
    if successor_user_pet_id.present?
      UserPet.where(id: successor_user_pet_id).update_all(predecessor_user_pet_id: nil)
    end
  end

  def update_need_flags!(ticks)
    ticks = ticks.to_i
    return if ticks <= 0

    flags = state_flags.deep_dup

    process_starving_flags!(flags, ticks)
    process_well_fed_flag!(flags, ticks)
    process_happy_flag!(flags, ticks)
    process_ticked_off_flag!(flags, ticks)
    process_perky_flag!(flags, ticks)

    self.state_flags = flags if flags != state_flags
  end

  def process_starving_flags!(flags, ticks)
    current_hunger = hunger.to_i
    if current_hunger < STARVING_THRESHOLD
      streak = flags.fetch('starving_streak', 0).to_i + ticks
      streak = STARVING_TICKS_REQUIRED if streak > STARVING_TICKS_REQUIRED
      flags['starving_streak'] = streak
      if streak >= STARVING_TICKS_REQUIRED
        flags['starving'] = true
        flags['starving_history'] = true
        flags['starving_grace'] = 0
      end
    else
      if (1...STARVING_TICKS_REQUIRED).cover?(flags.fetch('starving_streak', 0).to_i)
        flags['starving_oops'] = flags.fetch('starving_oops', 0).to_i + 1
      end
      flags['starving_streak'] = 0
      if current_hunger >= STARVING_RECOVERY_THRESHOLD
        flags['starving_grace'] = flags.fetch('starving_grace', 0).to_i + ticks
        if flags['starving_grace'].to_i >= STARVING_GRACE_LIMIT
          flags.delete('starving')
          flags['starving_grace'] = 0
        end
      else
        flags['starving_grace'] = 0
      end
    end
  end

  def process_well_fed_flag!(flags, ticks)
    current_hunger = hunger.to_i
    if current_hunger >= WELL_FED_THRESHOLD
      streak = flags.fetch('well_fed_streak', 0).to_i + ticks
      streak = WELL_FED_REQUIRED_TICKS if streak > WELL_FED_REQUIRED_TICKS
      flags['well_fed_streak'] = streak
      flags['well_fed_grace'] = 0
      if streak >= WELL_FED_REQUIRED_TICKS
        flags['well_fed'] = true
        if flags.delete('starving')
          flags['starving_resolved'] = true
        end
        flags['starving_streak'] = 0
        flags['starving_grace'] = 0
      end
    else
      if (1...WELL_FED_REQUIRED_TICKS).cover?(flags.fetch('well_fed_streak', 0).to_i)
        flags['well_fed_oops'] = flags.fetch('well_fed_oops', 0).to_i + 1
      end
      flags['well_fed_streak'] = 0
      if current_hunger < WELL_FED_LOSS_THRESHOLD
        grace = flags.fetch('well_fed_grace', 0).to_i + ticks
        flags['well_fed_grace'] = grace
        if grace >= WELL_FED_GRACE_LIMIT
          flags.delete('well_fed')
          flags['well_fed_grace'] = 0
        end
      else
        flags['well_fed_grace'] = 0
      end
    end
  end

  def process_happy_flag!(flags, ticks)
    current_mood     = mood.to_i
    current_boredom  = boredom.to_i
    if current_mood >= HAPPY_MOOD_THRESHOLD && current_boredom >= HAPPY_BOREDOM_MIN
      streak = flags.fetch('happy_streak', 0).to_i + ticks
      streak = HAPPY_REQUIRED_TICKS if streak > HAPPY_REQUIRED_TICKS
      flags['happy_streak'] = streak
      flags['happy_grace'] = 0
      if streak >= HAPPY_REQUIRED_TICKS
        flags['happy'] = true
        if flags.delete('ticked_off')
          flags['ticked_off_streak']   = 0
          flags['ticked_off_recovery'] = 0
        end
      end
    else
      if (1...HAPPY_REQUIRED_TICKS).cover?(flags.fetch('happy_streak', 0).to_i)
        flags['happy_oops'] = flags.fetch('happy_oops', 0).to_i + 1
      end
      flags['happy_streak'] = 0
      if flags['happy']
        grace = flags.fetch('happy_grace', 0).to_i + ticks
        flags['happy_grace'] = grace
        if grace >= HAPPY_GRACE_LIMIT || current_mood < HAPPY_LOSS_MOOD_THRESHOLD || current_boredom < HAPPY_LOSS_BOREDOM_THRESHOLD
          flags.delete('happy')
          flags['happy_grace'] = 0
        end
      else
        flags['happy_grace'] = 0
      end
    end
  end

  def process_ticked_off_flag!(flags, ticks)
    current_mood = mood.to_i
    if current_mood <= TICKED_OFF_MOOD_THRESHOLD
      streak = flags.fetch('ticked_off_streak', 0).to_i + ticks
      streak = TICKED_OFF_REQUIRED_TICKS if streak > TICKED_OFF_REQUIRED_TICKS
      flags['ticked_off_streak'] = streak
      flags['ticked_off_recovery'] = 0
      if streak >= TICKED_OFF_REQUIRED_TICKS
        flags['ticked_off'] = true
        flags.delete('happy')
        flags['happy_streak'] = 0
        flags['happy_grace']  = 0
        flags.delete('perky')
        flags['perky_streak'] = 0
        flags['perky_grace']  = 0
      end
    else
      if (1...TICKED_OFF_REQUIRED_TICKS).cover?(flags.fetch('ticked_off_streak', 0).to_i)
        flags['ticked_off_oops'] = flags.fetch('ticked_off_oops', 0).to_i + 1
      end
      flags['ticked_off_streak'] = 0
      if flags['ticked_off']
        if current_mood >= TICKED_OFF_RECOVERY_MOOD
          recovery = flags.fetch('ticked_off_recovery', 0).to_i + ticks
          if recovery >= TICKED_OFF_RECOVERY_STREAK
            flags.delete('ticked_off')
            flags['ticked_off_recovery'] = 0
          else
            flags['ticked_off_recovery'] = recovery
          end
        else
          flags['ticked_off_recovery'] = 0
        end
      end
    end
  end

  def process_perky_flag!(flags, ticks)
    current_mood     = mood.to_i
    current_boredom  = boredom.to_i
    if current_mood >= PERKY_MOOD_THRESHOLD && current_boredom >= PERKY_ENTERTAINMENT_THRESHOLD
      streak = flags.fetch('perky_streak', 0).to_i + ticks
      streak = PERKY_TICKS_REQUIRED if streak > PERKY_TICKS_REQUIRED
      flags['perky_streak'] = streak
      flags['perky_grace']  = 0
      if streak >= PERKY_TICKS_REQUIRED
        flags['perky'] = true
      end
    else
      if (1...PERKY_TICKS_REQUIRED).cover?(flags.fetch('perky_streak', 0).to_i)
        flags['perky_oops'] = flags.fetch('perky_oops', 0).to_i + 1
      end
      flags['perky_streak'] = 0
      if flags['perky']
        if current_mood >= PERKY_RECOVERY_THRESHOLD && current_boredom >= PERKY_RECOVERY_THRESHOLD
          flags['perky_grace'] = 0
        else
          grace = flags.fetch('perky_grace', 0).to_i + ticks
          if grace >= PERKY_GRACE_LIMIT
            flags.delete('perky')
            flags['perky_grace'] = 0
          else
            flags['perky_grace'] = grace
          end
        end
      else
        flags['perky_grace'] = 0
      end
    end
  end

  def load_ability_cache!
    return if defined?(@ability_references) && defined?(@ability_elements)

    refs = []
    elements = []

    abilities = if learned_abilities.loaded?
                  learned_abilities
                else
                  learned_abilities.select(:reference, :element_type)
                end

    abilities.each do |ability|
      refs << ability.reference.to_s if ability.reference.present?
      elements << ability.element_type.to_s if ability.element_type.present?
    end

    @ability_references = refs
    @ability_elements = elements
  end

  def assign_default_ability
    pool = pet.default_ability_pool
    granted_refs = []

    Array(pool[:standard]).each do |reference|
      grant_default_ability(reference, granted_refs)
    end

    if pool[:rare].any? && rand < RARE_CHANCE
      grant_default_ability(pool[:rare].sample, granted_refs)
    end
  end

  def grant_default_ability(reference, granted_refs)
    ref = reference.to_s.strip
    return if ref.blank? || granted_refs.include?(ref)

    ability = Ability.find_by(reference: ref)
    return unless ability

    user_pet_abilities.find_or_create_by!(ability: ability) do |entry|
      entry.unlocked_via = 'default'
    end

    granted_refs << ref
    @ability_references = nil
    @ability_elements = nil
  end
end
