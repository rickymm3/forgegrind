module InventoriesHelper
  RARITY_COLOR_MAP = {
    "legendary" => "orange-300",
    "epic" => "purple-300",
    "rare" => "blue-300",
    "uncommon" => "green-300",
    "common" => "slate-300",
    "currency" => "emerald-300"
  }.freeze

  RARITY_FRAME_MAP = {
    "legendary" => "border-orange-400/70",
    "epic" => "border-purple-400/70",
    "rare" => "border-blue-400/70",
    "uncommon" => "border-emerald-400/70",
    "common" => "border-slate-800/80",
    "currency" => "border-emerald-500/80"
  }.freeze

  def rarity_color_class(rarity)
    tone = RARITY_COLOR_MAP[rarity.to_s.downcase] || "slate-300"
    "#{tone}"
  end

  def rarity_frame_class(rarity)
    RARITY_FRAME_MAP[rarity.to_s.downcase] || RARITY_FRAME_MAP["common"]
  end

  def chest_frame_class(chest)
    case chest&.key
    when "pet_care_box_lvl2"
      rarity_frame_class("rare")
    else
      rarity_frame_class("uncommon")
    end
  end

  def container_count_badge_text(count)
    count = count.to_i
    count.zero? ? "Empty" : "#{count} owned"
  end

  def inventory_item_metadata(item)
    entry = inventory_item_catalog[item.item_type.to_s] || {}
    {
      rarity: (entry["rarity"] || "common").to_s,
      usable: ActiveModel::Type::Boolean.new.cast(entry["usable"]),
      target_type: entry["target_type"],
      description: entry["description"]
    }
  end

  def chest_icon_path(chest)
    path = chest&.icon.to_s
    return fallback_chest_icon if path.blank?

    asset_path(path)
  rescue StandardError => e
    if asset_missing?(e)
      fallback_chest_icon
    else
      raise
    end
  end

  private

  def inventory_item_catalog
    @inventory_item_catalog ||= if ItemsHelper::ITEM_CONFIG_PATH.exist?
                                  YAML.load_file(ItemsHelper::ITEM_CONFIG_PATH).with_indifferent_access
                                else
                                  {}.with_indifferent_access
                                end
  end

  def fallback_chest_icon
    asset_path(ItemsHelper::CARE_ITEM_PLACEHOLDER)
  rescue StandardError
    nil
  end

  def asset_missing?(error)
    (defined?(Propshaft::MissingAssetError) && error.is_a?(Propshaft::MissingAssetError)) ||
      (defined?(Sprockets::Rails::Helper::AssetNotFound) && error.is_a?(Sprockets::Rails::Helper::AssetNotFound)) ||
      error.is_a?(Errno::ENOENT)
  end
end
