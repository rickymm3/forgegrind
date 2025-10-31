class LootEntry < ApplicationRecord
  belongs_to :loot_table
  belongs_to :item

  validates :weight, numericality: { greater_than_or_equal_to: 0 }
  validates :qty_min, numericality: { greater_than_or_equal_to: 1 }
  validates :qty_max, numericality: { greater_than_or_equal_to: :qty_min }
  validates :rarity, presence: true

  def quantity_range
    qty_min..qty_max
  end
end
