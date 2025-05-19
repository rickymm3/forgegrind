class EnergyTickJob < ApplicationJob
  # … existing code …

  def perform
    User.includes(:user_stat, user_pets: :pet).find_each do |user|
      stat = user.user_stat
      next unless stat

      multiplier = stat.energy_multiplier
      gained     = (GameConfig::BASE_ENERGY_VALUE * multiplier).floor

      stat.increment!(:energy, gained)

      Turbo::StreamsChannel.broadcast_replace_to(
        "user_#{user.id}_energy",
        target: dom_id(user, :energy_display),
        partial: "shared/energy",
        locals: { user: user, user_stat: stat }
      )
    end
  end
end
