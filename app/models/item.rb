class Item < ApplicationRecord
  has_many :user_items, dependent: :destroy
  has_many :egg_item_costs, dependent: :destroy

  validates :name, :item_type, presence: true
end
