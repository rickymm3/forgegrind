class UserStat < ApplicationRecord
  belongs_to :user

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

  # Total multiplier: pets + future buffs
  def energy_multiplier
    total_power = user.user_pets.equipped.joins(:pet).sum("pets.power")
    1.0 + (total_power * 0.1)
  end
end
