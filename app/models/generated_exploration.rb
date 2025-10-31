class GeneratedExploration < ApplicationRecord
  belongs_to :user
  belongs_to :world
  has_many :user_explorations, dependent: :nullify

  scope :available, lambda {
    where(consumed_at: nil)
      .where("expires_at IS NULL OR expires_at >= ?", Time.current)
  }

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
    self[:duration_seconds].to_i
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
