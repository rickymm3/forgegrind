class World < ApplicationRecord
  has_many :user_explorations, dependent: :destroy
  has_and_belongs_to_many :pet_types

  validates :name, :duration, :reward_item_type, presence: true
  validates :duration, numericality: { only_integer: true, greater_than: 0 }

  scope :active, -> { where(enabled: true) }
  has_many :enemies, -> { order(:id) }, dependent: :destroy
  belongs_to :world

  has_and_belongs_to_many :users_who_unlocked, class_name: 'User', join_table: 'user_worlds' 
end
