class GeneratedExploration < ApplicationRecord
  belongs_to :user
  belongs_to :world
  has_many :user_explorations, dependent: :nullify

  SLOT_RANGE = (1..ExplorationGenerator::DEFAULT_COUNT).freeze
  SLOT_STATE_ACTIVE = "active".freeze
  SLOT_STATE_COOLDOWN = "cooldown".freeze

  scope :available, lambda {
    where(consumed_at: nil)
      .where("expires_at IS NULL OR expires_at >= ?", Time.current)
  }
  scope :ordered_by_slot, -> { order(:slot_index, :created_at) }

  validates :slot_index,
            inclusion: { in: SLOT_RANGE, allow_nil: true }

  def cooldown_active?
    cooldown_ends_at.present? && cooldown_ends_at.future?
  end

  def cooldown_remaining_seconds(reference_time: Time.current)
    return 0 unless cooldown_active?

    (cooldown_ends_at - reference_time).ceil
  end

  def clear_cooldown!
    update!(cooldown_ends_at: nil)
  end

  def begin_cooldown!(duration_seconds)
    update!(cooldown_ends_at: Time.current + duration_seconds)
  end

  def slot_state
    metadata_hash[:slot_state].presence || SLOT_STATE_ACTIVE
  end

  def slot_state_sym
    slot_state.to_sym
  end

  def set_slot_state!(state)
    write_metadata!(slot_state: state.to_s)
  end

  def reroll_available_at
    value = metadata_hash[:reroll_available_at]
    return nil if value.blank?

    value.is_a?(Time) ? value : Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def set_reroll_cooldown!(timestamp)
    data = metadata_hash
    if timestamp.present?
      data[:reroll_available_at] = timestamp.iso8601
    else
      data.delete(:reroll_available_at)
    end
    update!(metadata: data)
  end

  def clear_reroll_cooldown_if_elapsed!
    time = reroll_available_at
    return unless time.present? && time <= Time.current

    set_reroll_cooldown!(nil)
  end

  def reroll_cooldown_active?
    time = reroll_available_at
    time.present? && time.future?
  end

  def reroll_cooldown_remaining_seconds(reference_time: Time.current)
    return 0 unless reroll_cooldown_active?

    (reroll_available_at - reference_time).ceil
  end

  def requirements
    Array(self[:requirements]).map { |req| req.with_indifferent_access }
  end

  def reward_config
    (self[:reward_config] || {}).with_indifferent_access
  end

  def metadata
    (self[:metadata] || {}).with_indifferent_access
  end

  def duration_seconds
    segments = segment_definitions
    return self[:duration_seconds].to_i if segments.blank?

    segments.sum { |segment| segment[:duration_seconds].to_i }
  end

  def segment_definitions
    Array(self[:segment_definitions]).map do |entry|
      entry.respond_to?(:with_indifferent_access) ? entry.with_indifferent_access : entry
    end
  end

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def consumed?
    consumed_at.present?
  end

  def mark_consumed!
    update!(consumed_at: Time.current)
  end

  def requirements_progress_for(pets)
    pets = Array(pets)
    requirements.map do |req|
      current = count_requirement(req, pets)
      required = req[:required].to_i
      req.merge(
        current: current,
        fulfilled: current >= required
      )
    end
  end

  def requirements_summary_for(pets)
    progress = requirements_progress_for(pets)
    progress.group_by { |req| req[:source] || 'base' }
  end

  def fulfilled_requirement_ids(pets)
    requirements_progress_for(pets).select { |entry| entry[:fulfilled] }.map { |entry| entry[:id] }
  end

  private

  def metadata_hash
    (self[:metadata] || {}).with_indifferent_access
  end

  def write_metadata!(**updates)
    data = metadata_hash.merge(updates.compact)
    update!(metadata: data)
  end

  def count_requirement(req, pets)
    case req[:type]
    when 'pet_type'
      count_pet_type(pets, req[:key])
    when 'ability'
      count_ability(pets, req[:key])
    when 'level_min'
      count_level_min(pets, req[:value].to_i)
    when 'species'
      count_species(pets, req[:key])
    else
      0
    end
  end

  def count_pet_type(pets, type_name)
    return 0 if type_name.blank?

    pets.count do |pet|
      pet.pet.pet_types.any? { |pt| pt.name.casecmp?(type_name.to_s) }
    end
  end

  def count_ability(pets, ability_key)
    key = ability_key.to_s.strip
    return 0 if key.blank?

    target = key.downcase

    pets.count do |pet|
      references = pet.ability_references.map { |ref| ref.to_s.downcase }
      elements = pet.ability_elements.map { |element| element.to_s.downcase }
      references.include?(target) || elements.include?(target)
    end
  end

  def count_level_min(pets, level_min)
    pets.count { |pet| pet.level.to_i >= level_min }
  end

  def count_species(pets, species_name)
    return 0 if species_name.blank?

    pets.count do |pet|
      pet.pet.name.casecmp?(species_name.to_s)
    end
  end
end
