class UserStat < ApplicationRecord
  belongs_to :user
  validates :player_level, :hp_level, :attack_level,
            :defense_level, :luck_level, :attunement_level,
            numericality: { only_integer: true, greater_than: 0 }
  validates :player_experience,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # How many whole ticks have passed since last persistence
  def pending_ticks
    elapsed_seconds = (Time.current - energy_updated_at).to_i
    elapsed_seconds / GameConfig::BASE_TICK_INTERVAL.to_i
  end

  # Total energy accumulated since last persistence
  def pending_energy
    (pending_ticks * GameConfig::BASE_ENERGY_VALUE * energy_multiplier).floor
  end

  # Apply pending energy and advance the timestamp
  def catch_up!
    ticks = pending_ticks
    return if ticks.zero?

    increment!(:energy, pending_energy)

    update_column(
      :energy_updated_at,
      energy_updated_at + ticks * GameConfig::BASE_TICK_INTERVAL
    )
  end

  def player_level_cap
    GameConfig::PLAYER_LEVEL_CAP
  rescue NameError
    20
  end

  def player_level_maxed?
    player_level.to_i >= player_level_cap
  end

  def experience_to_next_level
    return 0 if player_level_maxed?
    threshold = level_xp_requirement(player_level)
    threshold - player_experience.to_i
  end

  def grant_player_experience!(amount)
    amount = amount.to_i
    return if amount <= 0

    with_lock do
      reload
      return if player_level_maxed?

      exp = player_experience.to_i + amount
      level = player_level.to_i

      while level < player_level_cap
        threshold = level_xp_requirement(level)
        break if exp < threshold

        exp -= threshold
        level += 1
      end

      exp = 0 if level >= player_level_cap

      update!(
        player_level: level,
        player_experience: exp
      )
    end
  end

  # Total multiplier: pets + future buffs
  def energy_multiplier
    total_power = user.user_pets.equipped.joins(:pet).sum("pets.power")
    1.0 + (total_power * 0.1)
  end

  def level_xp_requirement(level = player_level)
    level_xp_threshold(level)
  end

  HERO_UPGRADE_KEYS = %w[
    hatchers_luck
    swift_expeditions
    overflowing_care_boxes
    critical_care
  ].freeze

  def hero_upgrade_level(key)
    attribute = "#{key}_level"
    respond_to?(attribute) ? public_send(attribute).to_i : 0
  end

  def hero_upgrade_levels
    HERO_UPGRADE_KEYS.index_with { |key| hero_upgrade_level(key) }
  end

  def spent_hero_points
    hero_upgrade_levels.values.sum
  end

  def available_hero_points
    [player_level - spent_hero_points, 0].max
  end

  def hero_upgrade_cost(key)
    level = hero_upgrade_level(key)
    max = hero_upgrade_max_level(key)
    return nil if level >= max
    level + 1
  end

  def upgrade_hero_stat!(key)
    normalized_key = key.to_s
    raise ArgumentError, "Unknown hero stat #{key}" unless HERO_UPGRADE_KEYS.include?(normalized_key)

    cost = hero_upgrade_cost(normalized_key)
    raise StandardError, "Max level reached" unless cost
    raise StandardError, "Not enough hero points" if available_hero_points < cost

    attribute = "#{normalized_key}_level"
    update!(attribute => hero_upgrade_level(normalized_key) + 1)
  end

  def reset_hero_stats!
    attrs = HERO_UPGRADE_KEYS.index_with { 0 }
    update!(attrs)
  end

  private

  def level_xp_threshold(level)
    base   = GameConfig.const_defined?(:PLAYER_LEVEL_XP_BASE) ? GameConfig::PLAYER_LEVEL_XP_BASE : 100
    growth = GameConfig.const_defined?(:PLAYER_LEVEL_XP_GROWTH) ? GameConfig::PLAYER_LEVEL_XP_GROWTH : 50
    base + ([level.to_i, 1].max - 1) * growth
  end

  def hero_upgrade_max_level(_key)
    if GameConfig.respond_to?(:hero_upgrade_max_level)
      GameConfig.hero_upgrade_max_level(_key)
    elsif GameConfig.const_defined?(:HERO_UPGRADE_MAX_LEVEL)
      GameConfig::HERO_UPGRADE_MAX_LEVEL
    else
      5
    end
  end
end
