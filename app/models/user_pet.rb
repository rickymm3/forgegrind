class UserPet < ApplicationRecord
  belongs_to :user
  belongs_to :pet
  belongs_to :egg
  belongs_to :rarity

  scope :equipped, -> { where(equipped: true) }

end
