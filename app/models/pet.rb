class Pet < ApplicationRecord
  belongs_to :egg
  belongs_to :rarity
  validates :name, :power, presence: true 
  has_and_belongs_to_many :pet_types
  has_many :ability_permissions, as: :permitted, dependent: :destroy
  has_many :abilities, through: :ability_permissions
  belongs_to :default_ability, class_name: 'Ability', optional: true

end
