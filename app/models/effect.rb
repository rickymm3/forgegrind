class Effect < ApplicationRecord
  has_many :ability_effects, dependent: :destroy
  has_many :abilities, through: :ability_effects

  validates :name, presence: true
end
