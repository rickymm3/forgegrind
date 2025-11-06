module UserPetsHelper
  NEED_ATTENTION_THRESHOLD = 40

  def info_panel_dom_id(user_pet)
    ActionView::RecordIdentifier.dom_id(user_pet, :info_card)
  end

  def action_panel_dom_id(user_pet)
    ActionView::RecordIdentifier.dom_id(user_pet, :action_panel)
  end
  SPRITE_OVERRIDES = {
    "lupin"      => "nature-egg/lupin/lupin.webp",
    "fenra"      => "nature-egg/lupin/fenra.webp",
    "blazewulf"  => "nature-egg/lupin/blazewulf.webp",
    "duskhound"  => "nature-egg/lupin/duskhound.webp",
    "ironfang"   => "nature-egg/lupin/ironfang.webp",
    "galeclaw"   => "nature-egg/lupin/galeclaw.webp",
    "fenshadow"  => "nature-egg/lupin/fenshadow.webp",
    "pyrolune"   => "nature-egg/lupin/pyrolune.webp",
    "tempestral" => "nature-egg/lupin/tempestra.webp",
    "steelbane"  => "nature-egg/lupin/steelbane.webp",
    "aetherfang" => "nature-egg/lupin/aetherfang.webp"
  }.freeze

  def pet_sprite_path(pet)
    slug = pet.name.to_s.parameterize(separator: '_')
    candidates = []
    override = SPRITE_OVERRIDES[slug]
    candidates << override if override.present?
    candidates << "nature-egg/lupin/#{slug}.webp"
    candidates << "nature-egg/lupin/#{slug}.png"
    candidates << "pets/nature-egg/#{slug}.webp"
    candidates << "pets/nature-egg/#{slug}.png"
    candidates << "assets/nature-egg/lupin/#{slug}.webp"
    candidates << "assets/nature-egg/lupin/#{slug}.png"
    candidates << "pets/#{slug}.webp"
    candidates << "pets/#{slug}.png"
    candidates << "pets/#{slug}.jpg"

    candidates.compact.uniq.each do |logical_path|
      asset_url = asset_url_for(logical_path)
      return asset_url if asset_url
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

  private

  def asset_url_for(logical_path)
    ActionController::Base.helpers.asset_path(logical_path)
  rescue StandardError => e
    return nil if defined?(Propshaft::MissingAssetError) && e.is_a?(Propshaft::MissingAssetError)
    return nil if defined?(Sprockets::Rails::Helper::AssetNotFound) && e.is_a?(Sprockets::Rails::Helper::AssetNotFound)
    return nil if e.is_a?(Errno::ENOENT)
    raise
  end
end
