class Rarity < ApplicationRecord
  has_many :pets

  validates :name, :color, :weight, presence: true
  validates :glow_essence_multiplier,
            numericality: { only_integer: true, greater_than: 0 }
end
