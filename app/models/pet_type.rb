class PetType < ApplicationRecord
  has_many :pets, dependent: :nullify
  validates :name, presence: true, uniqueness: true
end
