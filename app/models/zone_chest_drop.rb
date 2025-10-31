class ZoneChestDrop < ApplicationRecord
  belongs_to :world
  belongs_to :chest_type

  validates :weight, numericality: { greater_than_or_equal_to: 0 }

  scope :for_zone, ->(world) { where(world: world).includes(:chest_type) }

  def self.weighted_pairs_for(world)
    for_zone(world).map do |drop|
      { chest_type: drop.chest_type, weight: drop.weight }
    end
  end
end
