class Egg < ApplicationRecord
  belongs_to :currency
  has_many :pets, dependent: :destroy
  has_many :egg_item_costs, dependent: :destroy
  has_many :items, through: :egg_item_costs
  has_one_attached :image

  accepts_nested_attributes_for :egg_item_costs,
                                allow_destroy: true,
                                reject_if: proc { |attrs| attrs['item_id'].blank? && attrs['quantity'].blank? }

  scope :enabled, -> { where(enabled: true) }
  
  validates :name, :cost_amount, presence: true
  
  def random_pet
    pets.includes(:rarity).flat_map { |pet| [pet] * pet.rarity.weight }.sample
  end

  def item_costs
    egg_item_costs.includes(:item).map { |cost| [cost.item.item_type, cost.quantity] }.to_h
  end
  
end
