class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :assign_nav_notification_count, if: :user_signed_in?

  private

  def assign_nav_notification_count
    return unless current_user

    current_user.user_explorations.where(completed_at: nil).find_each do |exploration|
      begin
        exploration.sync_segment_timers!
      rescue StandardError => e
        Rails.logger.debug { "[NavNotifications] Failed to inspect exploration ##{exploration.id}: #{e.message}" }
      end
    end

    @nav_notification_count = current_user.user_notifications.unread.count
  rescue StandardError => e
    Rails.logger.debug { "[NavNotifications] Error assigning notification count: #{e.message}" }
    @nav_notification_count = 0
  end

  def nav_tabbar_stream
    assign_nav_notification_count if user_signed_in?

    turbo_stream.replace(
      "primary-tabbar",
      partial: "shared/nav/tabbar",
      locals: { dom_id: "primary-tabbar" }
    )
  end
end
