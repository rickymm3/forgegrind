class EvolutionRule < ApplicationRecord
  belongs_to :parent_pet,    class_name: 'Pet'
  belongs_to :child_pet,     class_name: 'Pet'
  belongs_to :required_item, class_name: 'Item', optional: true

  # Support trigger level OR window range OR event-based rules.
  validate :window_presence
  validates :trigger_level,
            numericality: { only_integer: true, greater_than: 0 },
            allow_nil: true
  validate :guard_json_is_object

  private

  def window_presence
    has_trigger = trigger_level.present?
    has_range   = window_min_level.present? || window_max_level.present?
    has_event   = window_event.present?

    unless has_trigger || has_range || has_event
      errors.add(:base, "Provide a trigger_level, a level window, or a window_event")
    end
  end

  def guard_json_is_object
    return if guard_json.blank? || guard_json.is_a?(Hash)
    errors.add(:guard_json, "must be a JSON object")
  end
end
