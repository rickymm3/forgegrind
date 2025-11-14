module UserPetsHelper
  NEED_ATTENTION_THRESHOLD = 40

  def info_panel_dom_id(user_pet)
    ActionView::RecordIdentifier.dom_id(user_pet, :info_card)
  end

  def action_panel_dom_id(user_pet)
    ActionView::RecordIdentifier.dom_id(user_pet, :action_panel)
  end
  def pet_sprite_path(pet)
    filename = pet&.sprite_filename.presence || default_sprite_filename_for(pet)
    logical_paths = sprite_directories_for(pet).map { |dir| logical_asset_path(dir, filename) }
    logical_paths << "pets/#{filename}" if filename.present?

    logical_paths.compact.each do |logical_path|
      url = asset_url_for(logical_path)
      return url if url.present?
    end

    asset_url_for("pets/placeholder.svg") || ""
  end

  def need_label(key)
    {
      hunger:        "Hunger",
      hygiene:       "Hygiene",
      boredom:       "Entertainment",
      injury_level:  "Injury",
      mood:          "Mood"
    }[key.to_sym] || key.to_s.humanize
  end

  def need_bar_color(value)
    case value.to_i
    when 0..39   then "bg-red-500"
    when 40..69  then "bg-yellow-500"
    else              "bg-emerald-500"
    end
  end

  def need_trend_badge(value)
    case value.to_i
    when 0..39   then "text-red-600"
    when 40..69  then "text-yellow-600"
    else              "text-emerald-600"
    end
  end

  def pet_state_badges(user_pet)
    badges = []
    return badges unless user_pet

    if user_pet.exploring?
      badges << {
        label: "Exploring",
        class: "bg-indigo-500/90 border-indigo-300/60 text-white"
      }
    elsif user_pet.asleep_until.present? && Time.current < user_pet.asleep_until
      minutes_left = ((user_pet.asleep_until - Time.current) / 60).ceil
      badges << {
        label: "Sleeping",
        class: "bg-sky-500/90 border-sky-300/60 text-white",
        title: "Wakes in #{minutes_left} minute#{'s' if minutes_left != 1}"
      }
    end

    tracked_needs = %i[hunger hygiene boredom injury_level mood]
    low_needs = tracked_needs.select do |attr|
      user_pet.respond_to?(attr) && user_pet.send(attr).to_i < NEED_ATTENTION_THRESHOLD
    end

    if low_needs.any?
      badges << {
        label: "Needs Attention",
        class: "bg-rose-500/90 border-rose-300/60 text-white",
        title: low_needs.map { |attr| need_label(attr) }.join(', ')
      }
    end

    badges
  end

  def pet_sprite_logical_path(pet)
    filename = pet&.sprite_filename.presence || default_sprite_filename_for(pet)
    directory = sprite_directories_for(pet).first
    return "" unless filename.present?

    logical_asset_path(directory, filename) || "pets/#{filename}"
  end

  private

  def default_sprite_filename_for(pet)
    return "" unless pet
    "#{pet.name.to_s.parameterize(separator: '_')}.png"
  end

  def logical_asset_path(directory, filename)
    return nil unless filename.present?
    if directory.present?
      "pets/#{directory}/#{filename}"
    else
      "pets/#{filename}"
    end
  end

  def sprite_directories_for(pet)
    return [] unless pet

    dirs = []
    if evolution_form?(pet)
      dirs << base_form_directory(pet)
    end
    dirs << egg_directory(pet.egg)
    dirs.compact.uniq
  end

  def evolution_form?(pet)
    pet.evolves_from.exists? || pet.evolution_rules_as_child.exists?
  end

  def egg_directory(egg)
    return "egg-unknown" unless egg

    slug = egg.name.to_s.parameterize(separator: '_')
    slug = slug.sub(/_egg\z/, "")
    slug = slug.presence || "unknown"
    "egg-#{slug}"
  end

  def base_form_directory(pet)
    base = root_base_pet(pet)
    "base-#{base.name.to_s.parameterize(separator: '_')}"
  end

  def root_base_pet(pet)
    seen_ids = []
    current = pet

    loop do
      parent = current.evolves_from.first
      break unless parent
      break if seen_ids.include?(parent.id)

      seen_ids << parent.id
      current = parent
    end

    current
  end

  def asset_url_for(logical_path)
    ActionController::Base.helpers.asset_path(logical_path)
  rescue StandardError => e
    return nil if defined?(Propshaft::MissingAssetError) && e.is_a?(Propshaft::MissingAssetError)
    return nil if defined?(Sprockets::Rails::Helper::AssetNotFound) && e.is_a?(Sprockets::Rails::Helper::AssetNotFound)
    return nil if e.is_a?(Errno::ENOENT)
    raise
  end
end
