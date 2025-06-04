class Pet < ApplicationRecord
  belongs_to :egg
  belongs_to :rarity
  validates :name, :power, presence: true 
  belongs_to :pet_type, optional: true   # <– new association - should be false - need to change at some point!

end
