class Ability < ApplicationRecord
  has_many :ability_permissions, dependent: :destroy
  has_many :permitted_pet_types, through: :ability_permissions,
           source: :permitted, source_type: 'PetType'
  has_many :permitted_pets,      through: :ability_permissions,
           source: :permitted, source_type: 'Pet'
  has_many :user_pet_abilities, dependent: :destroy
  has_many :user_pets, through: :user_pet_abilities

  validates :damage, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :element_type, presence: true

  # back-reference for default assignment
  has_many :pets_as_default, class_name: 'Pet', foreign_key: 'default_ability_id'

  has_many :ability_effects, dependent: :destroy
  has_many :effects, through: :ability_effects
end
