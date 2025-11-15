class PetCareService
  class CareError < StandardError; end

  CARE_EXP_REWARD        = 1
  GLOW_ESSENCE_BOOST     = 1.5

  ACTIONS = {
    "play" => {
      energy_cost: 10,
      required_item_types: %w[frisbee],
      needs: { boredom: 20, hunger: -5, hygiene: -4, mood: 8 },
      personality: { playfulness: 1.0, curiosity: 0.5 },
      flag_counters: { plays_total: 1 }
    },
    "wash" => {
      energy_cost: 8,
      required_item_types: %w[soap],
      needs: { hygiene: 30, mood: 6 },
      personality: { temperament: 0.5 },
      flag_counters: { washes_total: 1 }
    },
    "treat" => {
      energy_cost: 6,
      required_item_types: %w[treat],
      needs: { injury_level: 18, mood: 5 },
      personality: { affection: 0.5 },
      flag_counters: { treats_total: 1 }
    },
    "feed" => {
      energy_cost: 5,
      required_item_types: %w[treat],
      needs: { hunger: 28, mood: 4 },
      personality: { temperament: 0.3 },
      flag_counters: { feeds_total: 1 }
    },
    "cuddle" => {
      energy_cost: 6,
      required_item_types: %w[blanket],
      needs: { mood: 12, boredom: 10 },
      personality: { affection: 1.0, playfulness: 0.2 },
      flag_counters: { cuddles_total: 1 }
    },
    "walk" => {
      energy_cost: 12,
      required_item_types: %w[map],
      needs: { boredom: 18, hunger: -8, hygiene: -6, mood: 9 },
      personality: { curiosity: 1.0, confidence: 0.5 },
      flag_counters: { walks_total: 1 }
    },
    "reprimand" => {
      energy_cost: 8,
      required_item_types: %w[whistle],
      needs: { mood: -12, boredom: -5 },
      personality: { temperament: 1.0 },
      flag_counters: { reprimands_total: 1 }
    },
    "explore" => {
      energy_cost: 12,
      required_item_types: %w[map],
      needs: { boredom: 15, hunger: -10, mood: 6 },
      personality: { curiosity: 0.8, confidence: 0.4 },
      flag_counters: { explores_total: 1 }
    }
  }.freeze

  def initialize(user_pet:, user:, interaction_type:, item_ids: [], glow_boost: false)
    @user_pet = user_pet
    @user = user
    @interaction_type = interaction_type.to_s
    @item_ids = Array(item_ids)
    @glow_boost = glow_boost
  end

  def run!
    definition = ACTIONS.fetch(@interaction_type) do
      raise CareError, "Unknown interaction: #{@interaction_type.inspect}"
    end

    result = { needs: {}, personality: {}, badges: [], flags: {} }

    UserPet.transaction do
      @user_pet.lock!
      ticks = @user_pet.catch_up_energy!
      @user_pet.catch_up_needs!(save: false, care_ticks: ticks)

      initial_mood = @user_pet.mood.to_f

      validate_energy!(definition)
      required_items = resolve_required_items(definition)
      crit_roll = roll_critical_care(definition, required_items: required_items)
      multiplier = glow_multiplier * crit_roll[:multiplier]

      spend_glow_essence!
      apply_energy_cost!(definition[:energy_cost])
      needs_result    = apply_needs(definition[:needs] || {}, boost_multiplier: multiplier)
      result[:needs]  = needs_result[:deltas]
      mood_adjustment = needs_result[:mood_delta]
      result[:personality] = apply_personality(definition[:personality] || {})
      apply_flag_counters(definition[:flag_counters] || {})

      consume_items!(required_items)

      @user_pet.recalc_mood!(save: false)
      if mood_adjustment != 0
        adjusted = @user_pet.send(:clamp_need, @user_pet.mood.to_f + mood_adjustment)
        @user_pet.mood = adjusted
      end
      final_mood = @user_pet.mood.to_f
      result[:needs][:mood] = final_mood - initial_mood

      if glow_boost?
        result[:glow] = { multiplier: multiplier }
      end
      result[:critical] = crit_roll if crit_roll[:triggered]

      exp_gain = grant_care_exp!
      result[:exp] = { gained: exp_gain, total: @user_pet.exp.to_i }

      @user_pet.good_day_tick!
      @user_pet.needs_updated_at = Time.current
      @user_pet.save!(validate: false)

      result[:badges] = @user_pet.badges
      result[:flags]  = @user_pet.state_flags
    end

    result
  end

  private

  attr_reader :user_pet, :user, :item_ids, :glow_boost

  def validate_energy!(definition)
    cost = definition[:energy_cost].to_i
    return if cost.zero?

    if user_pet.energy.to_i < cost
      raise UserPet::NotEnoughEnergyError, "#{user_pet.pet.name} doesn’t have enough energy."
    end
  end

  def apply_energy_cost!(cost)
    return if cost.to_i <= 0

    user_pet.spend_energy!(cost.to_i)
  end

  def apply_needs(needs_hash, boost_multiplier: 1.0)
    deltas = {}
    mood_delta = 0.0

    needs_hash.each do |attr, delta|
      attr = attr.to_sym
      value = delta.to_f
      boosted_value = if boost_multiplier > 1.0 && value.positive?
                        value * boost_multiplier
                      else
                        value
                      end

      if attr == :mood
        mood_delta += boosted_value
        next
      end

      next unless user_pet.respond_to?(attr)

      current = user_pet.send(attr).to_f
      updated = user_pet.send(:clamp_need, current + boosted_value)
      user_pet.send("#{attr}=", updated)
      deltas[attr] = updated - current
    end

    { deltas: deltas, mood_delta: mood_delta }
  end

  def apply_personality(personality_hash)
    deltas = {}

    personality_hash.each do |attr, delta|
      next unless user_pet.respond_to?(attr)
      current = user_pet.send(attr).to_f
      updated = current + delta.to_f
      user_pet.send("#{attr}=", updated)
      deltas[attr.to_sym] = delta.to_f
    end

    deltas
  end

  def apply_flag_counters(counters)
    return if counters.blank?

    flags = user_pet.state_flags.deep_dup
    counters.each do |key, increment|
      str_key = key.to_s
      flags[str_key] = flags[str_key].to_i + increment.to_i
    end
    user_pet.state_flags = flags
  end

  def resolve_required_items(definition)
    types = Array(definition[:required_item_types])
    return [] if types.blank?

    types.map do |item_type|
      find_item_for_type(item_type.to_s)
    end
  end

  def find_item_for_type(item_type)
    item = Item.find_by(item_type: item_type) || Item.find_by(name: item_type)
    raise CareError, "Required item #{item_type.inspect} not found." unless item

    user_item = if item_ids.present?
                  user.user_items.find_by(id: item_ids.shift)
                else
                  user.user_items.find_by(item_id: item.id)
                end

    unless user_item&.quantity.to_i.positive?
      raise CareError, "You need a #{item.name} to perform this action."
    end

    user_item
  end

  def consume_items!(user_items)
    user_items.each do |user_item|
      next unless user_item

      if user_item.quantity.to_i <= 1
        user_item.destroy!
      else
        user_item.update!(quantity: user_item.quantity - 1)
      end
    end
  end

  def glow_boost?
    glow_boost == true
  end

  def glow_multiplier
    glow_boost? ? GLOW_ESSENCE_BOOST : 1.0
  end

  def spend_glow_essence!
    return unless glow_boost?

    stat = user.user_stat
    unless stat
      stat = user.create_user_stat!(User::STAT_DEFAULTS.merge(energy_updated_at: Time.current))
    end

    stat.with_lock do
      if stat.glow_essence.to_i <= 0
        raise CareError, "Not enough Glow Essence."
      end
      stat.update!(glow_essence: stat.glow_essence.to_i - 1)
    end
  end

  def grant_care_exp!
    return 0 if user_pet.level.to_i >= UserPet::LEVEL_CAP

    current_exp = user_pet.exp.to_i
    exp_cap     = UserPet::EXP_PER_LEVEL
    return 0 if current_exp >= exp_cap

    gained = [CARE_EXP_REWARD, exp_cap - current_exp].min
    user_pet.exp = current_exp + gained
    gained
  end

  def roll_critical_care(definition, required_items:)
    return base_crit_result unless Array(definition[:required_item_types]).present? && required_items.present?

    level = hero_stat&.hero_upgrade_level(:critical_care).to_i
    return base_crit_result if level <= 0

    chance = GameConfig.critical_care_crit_chance(level)
    triggered = random.rand < chance
    multiplier = triggered ? GameConfig.critical_care_crit_multiplier : 1.0

    {
      triggered: triggered,
      chance: chance,
      multiplier: multiplier
    }
  rescue StandardError
    base_crit_result
  end

  def base_crit_result
    { triggered: false, chance: 0.0, multiplier: 1.0 }
  end

  def hero_stat
    @hero_stat ||= user.ensure_user_stat
  rescue StandardError
    nil
  end

  def random
    @random ||= Random.new
  end
end
