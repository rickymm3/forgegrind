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
        path: adopt_path,
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
end
