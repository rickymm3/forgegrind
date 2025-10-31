class UserContainer < ApplicationRecord
  belongs_to :user
  belongs_to :chest_type

  scope :for_user, ->(user) { where(user: user) }
  scope :containers_available, -> { where("count > 0") }

  validates :count, numericality: { greater_than_or_equal_to: 0 }

end
