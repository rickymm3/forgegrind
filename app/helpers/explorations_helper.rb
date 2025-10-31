module ExplorationsHelper
  IMAGE_EXTENSIONS = %w[jpg jpeg png webp svg].freeze

  def world_zone_image_path(world)
    slug = world.name.to_s.parameterize
    IMAGE_EXTENSIONS.each do |ext|
      candidate = "zones/#{slug}.#{ext}"
      return asset_path(candidate) if asset_exists?(candidate)
    end

    asset_path("zones/placeholder-zone.svg")
  end

  private

  def asset_exists?(logical_path)
    if Rails.application.config.assets.compile
      Rails.application.assets&.find_asset(logical_path).present?
    else
      Rails.application.assets_manifest&.assets&.key?(logical_path)
    end
  rescue StandardError
    false
  end
end
