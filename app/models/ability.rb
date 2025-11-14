# app/models/ability.rb
class Ability < ApplicationRecord
  # Which pet types and specific pets may learn this ability
  has_many :ability_permissions, dependent: :destroy
  has_many :permitted_pet_types,
           through: :ability_permissions,
           source: :permitted,
           source_type: 'PetType'
  has_many :permitted_pets,
           through: :ability_permissions,
           source: :permitted,
           source_type: 'Pet'

  # Which UserPets have learned this ability
  has_many :user_pet_abilities, dependent: :destroy
  has_many :user_pets,
           through: :user_pet_abilities

  # Any additional effects (buffs/debuffs, etc.)
  has_many :ability_effects, dependent: :destroy
  has_many :effects,
           through: :ability_effects

  # Core metadata stored in the DB
  validates :name, :reference, :description, :element_type, presence: true
  validates :reference, uniqueness: true

  accepts_nested_attributes_for :ability_permissions, allow_destroy: true
  accepts_nested_attributes_for :ability_effects, allow_destroy: true
end
