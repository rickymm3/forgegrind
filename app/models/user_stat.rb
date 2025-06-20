class UserStat < ApplicationRecord
  belongs_to :user
  validates :player_level, :hp_level, :attack_level,
            :defense_level, :luck_level, :attunement_level,
            numericality: { only_integer: true, greater_than: 0 }

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

  # How many trophies you need to spend to gain your next player_level point
  def next_level_cost
    GameConfig.cost_for_level(player_level)
  end

  # Whether the user has enough trophies to level up
  def can_level_up?
    trophies >= next_level_cost
  end

  # Spend trophies and bump player_level by 1
  def level_up!
    raise "Not enough trophies" unless can_level_up?

    update!(
      trophies:     trophies - next_level_cost,
      player_level: player_level + 1
    )
  end

  # Total multiplier: pets + future buffs
  def energy_multiplier
    total_power = user.user_pets.equipped.joins(:pet).sum("pets.power")
    1.0 + (total_power * 0.1)
  end
end
