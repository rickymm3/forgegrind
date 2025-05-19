class UserItem < ApplicationRecord
  belongs_to :user
  belongs_to :item

  validates :quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # increment or create
  def self.add_to_inventory(user, item, amount = 1)
    record = find_or_initialize_by(user: user, item: item)
    record.quantity += amount
    record.save!
    record
  end
end
