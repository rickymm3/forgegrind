class UserPetAbility < ApplicationRecord
  belongs_to :user_pet
  belongs_to :ability
end
