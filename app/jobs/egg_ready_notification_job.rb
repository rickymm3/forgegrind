class EggReadyNotificationJob < ApplicationJob
  queue_as :default

  def perform(user_egg_id)
    egg = UserEgg.find(user_egg_id)
    return unless egg.ready_to_hatch?

    egg.notify_ready_for_hatching!
  end
end
