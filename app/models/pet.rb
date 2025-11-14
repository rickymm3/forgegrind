# app/models/pet.rb

class Pet < ApplicationRecord
  belongs_to :egg, optional: true
  belongs_to :rarity
  belongs_to :special_ability, optional: true
  belongs_to :default_ability, class_name: "Ability", optional: true

  validates :name, :power, presence: true
  validates :hatch_weight, numericality: { only_integer: true, greater_than: 0 }

  has_and_belongs_to_many :pet_types

  # All permissions granting this pet type access to abilities
  has_many :ability_permissions, as: :permitted, dependent: :destroy
  has_many :abilities, through: :ability_permissions

  # Abilities this pet type starts with (via permission records)
  has_many :default_abilities,
           through: :ability_permissions,
           source: :ability

  has_many :evolution_rules_as_parent,
           class_name: "EvolutionRule",
           foreign_key: :parent_pet_id,
           dependent: :destroy,
           inverse_of: :parent_pet
  has_many :evolution_rules_as_child,
           class_name: "EvolutionRule",
           foreign_key: :child_pet_id,
           dependent: :destroy,
           inverse_of: :child_pet
  has_many :evolves_into, through: :evolution_rules_as_parent, source: :child_pet
  has_many :evolves_from, through: :evolution_rules_as_child, source: :parent_pet
  has_many :user_pets, dependent: :restrict_with_error

  before_validation :assign_default_special_ability, if: -> { special_ability_id.blank? }
  before_validation :assign_default_sprite_filename, if: -> { sprite_filename.blank? && name.present? }

  # Load the YAML mapping and return two arrays for this pet:
  #   :standard => [ "tackle", "growl" ], 
  #   :rare     => [ "whirlwind" ]
  def default_ability_pool
    mapping = YAML.load_file(Rails.root.join("config", "pet_default_abilities.yml"))
    entry   = mapping[name.downcase] || {}
    {
      standard: Array(entry["standard"]),
      rare:     Array(entry["rare"])
    }
  end

  private

  def assign_default_special_ability
    reference = PetSpecialAbilityCatalog.default_reference_for(name)
    return if reference.blank?

    self.special_ability ||= SpecialAbility.find_by(reference: reference)
  end

  def assign_default_sprite_filename
    self.sprite_filename = "#{name.to_s.parameterize(separator: '_')}.png"
  end
end
