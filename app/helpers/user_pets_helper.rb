module UserPetsHelper
  NEED_ATTENTION_THRESHOLD = 40
  CARE_ALERT_THRESHOLD     = 60
  CARE_ALERT_COOLDOWN      = 3.minutes

  CARE_ALERT_CATALOG = {
    hunger: {
      action: "feed",
      icon: "🍖",
      prompt: "I'm hungry!",
      description: "Offer a hearty meal to refill energy and mood.",
      cta_label: "Feed",
      item_type: "treat"
    },
    hygiene: {
      action: "wash",
      icon: "🧼",
      prompt: "I need a bath!",
      description: "Give your pet a quick scrub to restore hygiene.",
      cta_label: "Start bath",
      item_type: "soap"
    },
    boredom: {
      action: "play",
      icon: "🎾",
      prompt: "Let's play!",
      description: "Toss a frisbee or explore to shake off boredom.",
      cta_label: "Playtime",
      item_type: "frisbee"
    },
    injury_level: {
      action: "treat",
      icon: "💊",
      prompt: "I need first aid.",
      description: "Patch injuries to keep your pet comfortable.",
      cta_label: "Treat injury",
      item_type: "treat"
    },
    mood: {
      action: "cuddle",
      icon: "🤗",
      prompt: "I need some comfort.",
      description: "A cozy cuddle will lift their spirits.",
      cta_label: "Comfort",
      item_type: "blanket"
    }
  }.freeze

  def info_panel_dom_id(user_pet)
    ActionView::RecordIdentifier.dom_id(user_pet, :info_card)
  end

  def action_panel_dom_id(user_pet)
    ActionView::RecordIdentifier.dom_id(user_pet, :action_panel)
  end

  def pet_stats_dom_id(user_pet)
    ActionView::RecordIdentifier.dom_id(user_pet, :care_stats)
  end

  def care_alert_dom_id(user_pet)
    ActionView::RecordIdentifier.dom_id(user_pet, :care_alerts)
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

  def rarity_border_class(rarity)
    slug = rarity&.name.to_s.parameterize(separator: '-').presence || "common"
    "pet-panel__media--rarity-#{slug}"
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

  def care_item_details_lookup
    @care_item_details_lookup ||= begin
      path = Rails.root.join("config/items.yml")
      path.exist? ? YAML.load_file(path).with_indifferent_access : {}.with_indifferent_access
    end
  end

  def care_item_counts_for(user)
    return {} unless user

    user.user_items.includes(:item).each_with_object(Hash.new(0)) do |user_item, memo|
      type = user_item.item&.item_type
      next unless type

      memo[type.to_s] += user_item.quantity.to_i
    end
  end

  def care_alerts_for(user_pet, item_counts:, threshold: CARE_ALERT_THRESHOLD)
    return [] unless user_pet

    counts = item_counts || {}
    item_lookup = care_item_details_lookup
    cooldowns = current_care_alert_cooldowns

    CARE_ALERT_CATALOG.filter_map do |metric, config|
      next unless user_pet.respond_to?(metric)

      value = user_pet.send(metric).to_f
      next unless value < threshold
      next if care_alert_suppressed?(metric, cooldowns)

      item_type = config[:item_type]
      quantity = item_type ? counts[item_type.to_s].to_i : 0
      item_meta = item_type ? item_lookup[item_type.to_s] || {} : {}
      item_name = item_meta[:name] || item_meta["name"] || item_type&.to_s&.humanize

      {
        key: metric,
        action: config[:action],
        icon: config[:icon],
        prompt: config[:prompt],
        description: config[:description],
        cta_label: config[:cta_label] || "Help now",
        title: need_label(metric),
        item_type: item_type,
        item_quantity: quantity,
        item_name: item_name,
        value: value.round(1),
        percent: value.clamp(UserPet::NEEDS_MIN, UserPet::NEEDS_MAX).round(1)
      }
    end
  end

  def pet_feeling_descriptor(user_pet)
    return nil unless user_pet

    if user_pet.pet_thought.present?
      build_feeling_hash(user_pet.pet_thought.thought, :active)
    elsif user_pet.thought_suppressed? && user_pet.thought_expires_at.present?
      build_feeling_hash("Feeling calm and content.", :calm)
    else
      nil
    end
  end

  def pet_sprite_logical_path(pet)
    filename = pet&.sprite_filename.presence || default_sprite_filename_for(pet)
    directory = sprite_directories_for(pet).first
    return "" unless filename.present?

    logical_asset_path(directory, filename) || "pets/#{filename}"
  end

  def record_care_alert_snooze!(metric)
    return if metric.blank?

    session[:care_alert_cooldowns] ||= {}
    session[:care_alert_cooldowns][metric.to_s] = CARE_ALERT_COOLDOWN.from_now.to_i
  end

  def current_care_alert_cooldowns
    raw = session[:care_alert_cooldowns] || {}
    now = Time.current.to_i
    raw.select { |_key, ts| ts.to_i > now }
  end

  def care_alert_suppressed?(metric, cooldowns)
    return false unless metric && cooldowns
    cooldowns[metric.to_s].to_i > Time.current.to_i
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

  def build_feeling_hash(text, tone)
    card_class = case tone
                 when :calm
                   "bg-slate-950/75 border border-slate-500/30 text-slate-100"
                 else
                   "bg-indigo-900/80 border border-indigo-500/50 text-indigo-100"
                 end

    {
      label: text,
      tone: tone,
      card_class: card_class
    }
  end
end
