class PetType < ApplicationRecord
  has_and_belongs_to_many :pets
  has_and_belongs_to_many :worlds   # if you also created worlds↔pet_types join

  has_many :ability_permissions, as: :permitted, dependent: :destroy
  has_many :abilities, through: :ability_permissions

  validates :name, presence: true, uniqueness: true
end
