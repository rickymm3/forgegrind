class NotificationsController < ApplicationController
  before_action :authenticate_user!

  def index
    unread_ids = current_user.user_notifications.unread.pluck(:id)
    if unread_ids.any?
      timestamp = Time.current
      current_user.user_notifications.where(id: unread_ids).update_all(read_at: timestamp, updated_at: timestamp)
      assign_nav_notification_count
    end

    @freshly_read_ids = unread_ids
    @notifications = current_user.user_notifications.recent_first
  end

  def clear_all
    timestamp = Time.current
    current_user.user_notifications.unread.update_all(read_at: timestamp, updated_at: timestamp)
    assign_nav_notification_count
    respond_to do |format|
      format.html do
        redirect_to notifications_path, notice: "All notifications cleared."
      end
      format.turbo_stream do
        @notifications = current_user.user_notifications.recent_first
        render turbo_stream: [
          turbo_stream.replace(
            "notifications-list",
            partial: "notifications/list",
            locals: {
              notifications: @notifications,
              freshly_read_ids: []
            }
          ),
          nav_tabbar_stream
        ]
      end
    end
  end
end
