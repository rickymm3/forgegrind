class AbilityEffect < ApplicationRecord
  belongs_to :ability
  belongs_to :effect

  validates :magnitude, numericality: { greater_than_or_equal_to: 0 }
  validates :duration,  numericality: { greater_than_or_equal_to: 0 }
end
