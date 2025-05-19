class EggItemCost < ApplicationRecord
  belongs_to :egg
  belongs_to :item

  validates :quantity, numericality: { greater_than: 0 }
end
