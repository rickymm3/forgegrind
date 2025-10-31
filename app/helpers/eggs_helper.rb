module EggsHelper
  EGG_IMAGE_PATTERNS = [
    "eggs/%{slug}.png",
    "eggs/%{slug}.webp",
    "eggs/%{slug}.jpg"
  ].freeze
  EGG_PLACEHOLDER = "eggs/placeholder.png"

  def egg_image_path(egg)
    slug = egg.name.to_s.parameterize(separator: '-')

    EGG_IMAGE_PATTERNS.each do |pattern|
      logical = format(pattern, slug: slug)
      return asset_path(logical) if asset_exists?(logical)
    end

    asset_exists?(EGG_PLACEHOLDER) ? asset_path(EGG_PLACEHOLDER) : nil
  end

  private

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
