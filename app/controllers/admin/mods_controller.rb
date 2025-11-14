require "ostruct"

class Admin::ModsController < Admin::BaseController
  def index
    library = ExplorationModLibrary
    @bases = present_collection(library.base_mods)
    @prefixes = present_collection(library.prefix_mods)
    @suffixes = present_collection(library.suffix_mods)
  end

  private

  def present_collection(collection)
    Array(collection).map do |key, config|
      OpenStruct.new(
        key: key,
        label: config[:label] || key.to_s.titleize,
        description: config[:description],
        duration_multiplier: config[:duration_multiplier],
        rewards: config[:rewards],
        requirements: Array(config[:requirements]),
        raw: config
      )
    end
  end
end
