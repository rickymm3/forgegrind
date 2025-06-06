class PetType < ApplicationRecord
  has_and_belongs_to_many :pets
  has_and_belongs_to_many :worlds   # if you also created worlds↔pet_types join

  validates :name, presence: true, uniqueness: true
end
