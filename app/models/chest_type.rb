class ChestType < ApplicationRecord
  belongs_to :default_loot_table, class_name: "LootTable"
  has_many :user_containers, dependent: :destroy
  has_many :zone_chest_drops, dependent: :destroy

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true
  validates :icon, presence: true
  validates :min_level, numericality: { greater_than_or_equal_to: 1 }
end
