# app/models/pet.rb

class Pet < ApplicationRecord
  belongs_to :egg
  belongs_to :rarity
  belongs_to :special_ability, optional: true

  validates :name, :power, presence: true

  has_and_belongs_to_many :pet_types

  # All permissions granting this pet type access to abilities
  has_many :ability_permissions, as: :permitted, dependent: :destroy
  has_many :abilities, through: :ability_permissions

  # Abilities this pet type starts with (via permission records)
  has_many :default_abilities,
           through: :ability_permissions,
           source: :ability

  before_validation :assign_default_special_ability, if: -> { special_ability_id.blank? }

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
end
