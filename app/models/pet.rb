class Pet < ApplicationRecord
  belongs_to :egg
  belongs_to :rarity
  validates :name, :power, presence: true 
  has_and_belongs_to_many :pet_types

end
