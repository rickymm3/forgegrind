class Rarity < ApplicationRecord
  has_many :pets

  validates :name, :color, :weight, presence: true
end
