module ApplicationHelper
  def primary_tab_items
    [
      {
        id: :pets,
        label: "Pets",
        path: user_pets_path,
        description: "View your companions and eggs."
      },
      {
        id: :store,
        label: "Store",
        path: store_path,
        description: "Visit the store to adopt new eggs."
      },
      {
        id: :explore,
        label: "Explore",
        path: explorations_path,
        description: "Scout zones and embark on runs."
      }
    ]
  end

  def active_tab_id
    case controller_path
    when "user_pets", "nursery", "user_eggs", "pets"
      :pets
    when "adopt"
      :store
    when "explorations", "user_explorations"
      :explore
    else
      nil
    end
  end

  def nav_notification_count
    if defined?(@nav_notification_count) && !@nav_notification_count.nil?
      @nav_notification_count.to_i
    elsif defined?(current_user) && current_user.respond_to?(:pending_notifications_count)
      current_user.pending_notifications_count.to_i
    else
      0
    end
  rescue StandardError
    0
  end

  def nav_notifications?
    nav_notification_count.positive?
  end
end
