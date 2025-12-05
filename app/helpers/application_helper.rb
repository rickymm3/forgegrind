module ApplicationHelper
  def primary_tab_items
    [
      {
        id: :pets,
        label: "Pets",
        path: pets_path,
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
      },
      {
        id: :inventory,
        label: "Inventory",
        path: inventory_path,
        description: "View items and containers."
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
    when "inventories"
      :inventory
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

  def admin_namespace?
    controller_path.start_with?("admin/")
  end

  def admin_nav_items
    [
      { label: "Dashboard", path: admin_root_path },
      { label: "Content Desk", path: admin_content_path },
      { label: "Eggs", path: admin_eggs_path },
      { label: "Pets", path: admin_pets_path },
      { label: "Abilities", path: admin_abilities_path },
      { label: "Special Abilities", path: admin_special_abilities_path },
      { label: "Evolution Rules", path: admin_evolution_rules_path },
      { label: "Worlds", path: admin_worlds_path },
      { label: "Exploration Worlds", path: admin_exploration_bases_path },
      { label: "Badges", path: admin_badges_path },
      { label: "Mods", path: admin_mods_path },
      { label: "Affixes", path: admin_affixes_path },
      { label: "Suffixes", path: admin_suffixes_path },
      { label: "Encounters", path: admin_encounters_path },
      { label: "User Pets", path: admin_user_pets_path }
    ]
  end

  def admin_nav_link_classes(path)
    base = "inline-flex items-center rounded-full px-3 py-1 text-xs font-semibold transition"
    if current_page?(path)
      "#{base} bg-indigo-600 text-white"
    else
      "#{base} border border-slate-600 text-slate-200 hover:border-indigo-400 hover:text-white"
    end
  end

  def badge_label_for(key)
    definition = BadgeRegistry.find(key)
    definition&.label || key.to_s.titleize
  end

  def admin_related_link(label, path, icon: "↗")
    link_to path,
            class: "inline-flex items-center gap-1 rounded-full border border-slate-300 px-3 py-1 text-xs font-semibold text-slate-600 hover:border-indigo-400 hover:text-indigo-500 transition",
            target: "_self" do
      safe_join([content_tag(:span, label), content_tag(:span, icon, class: "text-[10px]")])
    end
  end

  def admin_related_links(links = [])
    return if links.blank?

    content_tag :div, class: "flex flex-wrap gap-2" do
      safe_join(links.map { |link| admin_related_link(link[:label], link[:path], icon: link[:icon] || "↗") })
    end
  end

  def user_pet_panel_dom_id(user_pet)
    ActionView::RecordIdentifier.dom_id(user_pet, :panel)
  end

  def badge_registry_definitions
    BadgeRegistry.definitions.values.sort_by(&:label)
  end

  def guard_badge_keys_for(rule)
    guard = rule&.guard_json
    guard = guard.to_h if guard.respond_to?(:to_h) && !guard.is_a?(Hash)
    return [] unless guard.is_a?(Hash)

    conditions = Array(guard["all"]) + Array(guard["any"])
    conditions.filter_map do |condition|
      next unless condition.is_a?(Hash)
      next unless condition["type"].to_s == "badge_unlocked"
      (condition["key"] || condition["value"]).to_s
    end.uniq
  end
end
