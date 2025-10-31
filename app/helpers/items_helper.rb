module ItemsHelper
  ITEM_DETAILS_PATH = Rails.root.join("config", "item_details.yml")
  CARE_ITEM_PLACEHOLDER = "items/care/placeholder.png"
  CARE_ITEM_PATTERNS = [
    "items/care/%{slug}.png",
    "items/care/%{slug}.webp",
    "items/%{slug}.png",
    "items/%{slug}.webp"
  ].freeze

  def item_description(item)
    details = load_item_details[item.item_type.to_s]
    details.is_a?(Hash) ? details["description"] : nil
  end

  def care_item_image_path(item_type)
    slug = item_type.to_s.parameterize(separator: '_')

    CARE_ITEM_PATTERNS.each do |pattern|
      logical_path = format(pattern, slug: slug)
      return asset_path(logical_path) if asset_exists?(logical_path)
    end

    return asset_path(CARE_ITEM_PLACEHOLDER) if asset_exists?(CARE_ITEM_PLACEHOLDER)

    nil
  end

  private

  def load_item_details
    @item_details_cache ||= begin
      if ITEM_DETAILS_PATH.exist?
        YAML.load_file(ITEM_DETAILS_PATH).with_indifferent_access
      else
        {}.with_indifferent_access
      end
    end
  end

  def asset_exists?(logical_path)
    ActionController::Base.helpers.asset_path(logical_path)
    true
  rescue StandardError => e
    return false if defined?(Propshaft::MissingAssetError) && e.is_a?(Propshaft::MissingAssetError)
    return false if defined?(Sprockets::Rails::Helper::AssetNotFound) && e.is_a?(Sprockets::Rails::Helper::AssetNotFound)
    return false if e.is_a?(Errno::ENOENT)
    raise
  end
end
