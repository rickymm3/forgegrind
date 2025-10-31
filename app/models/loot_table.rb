class LootTable < ApplicationRecord
  has_many :loot_entries, dependent: :destroy

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true
  validates :rolls_min, numericality: { greater_than_or_equal_to: 0 }
  validates :rolls_max, numericality: { greater_than_or_equal_to: :rolls_min }

  def rolls_range
    rolls_min..rolls_max
  end
end
