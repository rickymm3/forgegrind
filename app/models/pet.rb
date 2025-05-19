class Pet < ApplicationRecord
  belongs_to :egg
  belongs_to :rarity
  validates :name, :power, presence: true
end
