# app/models/pet_thought.rb

class PetThought < ApplicationRecord
  validates :thought, presence: true, uniqueness: true

  validates :playfulness_mod, :affection_mod,
            :temperament_mod, :curiosity_mod,
            :confidence_mod,
            presence: true,
            numericality: { greater_than: 0 }
end
