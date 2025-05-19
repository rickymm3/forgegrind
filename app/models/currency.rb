class Currency < ApplicationRecord
  has_many :eggs

  validates :name, presence: true, uniqueness: true
end
