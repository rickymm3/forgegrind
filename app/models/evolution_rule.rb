class EvolutionRule < ApplicationRecord
  belongs_to :parent_pet,    class_name: 'Pet'
  belongs_to :child_pet,     class_name: 'Pet'
  belongs_to :required_item, class_name: 'Item', optional: true

  validates :trigger_level,
            presence: true,
            numericality: { only_integer: true, greater_than: 0 }
end
