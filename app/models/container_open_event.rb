class ContainerOpenEvent < ApplicationRecord
  belongs_to :user
  belongs_to :chest_type

  validates :request_uuid, presence: true, uniqueness: true
  validates :opened_qty, numericality: { greater_than_or_equal_to: 0 }
end
