# app/models/user_pet.rb

class UserPet < ApplicationRecord
  belongs_to :user
  belongs_to :pet
  belongs_to :egg
  belongs_to :rarity
  belongs_to :pet_thought, optional: true

  has_many :user_pet_abilities, dependent: :destroy
  has_many :learned_abilities, through: :user_pet_abilities, source: :ability

  scope :equipped, -> { where(equipped: true) }

  LEVEL_CAP        = 5
  EXP_PER_LEVEL    = 100
  MAX_ENERGY       = 100
  ENERGY_INTERVAL  = 5.minutes

  BASE_IMPACTS = {
    "play" =>      { playfulness:  2.0, affection:  1.0, temperament:  0.0, curiosity:  1.0, confidence:  0.0 },
    "cuddle" =>    { playfulness:  0.5, affection:  2.5, temperament: -0.5, curiosity:  0.0, confidence:  1.0 },
    "reprimand" => { playfulness: -1.0, affection: -1.5, temperament:  2.0, curiosity:  0.0, confidence:  0.5 },
    "feed" =>      { playfulness:  0.0, affection:  1.5, temperament:  0.0, curiosity:  2.0, confidence:  0.0 },
    "explore" =>   { playfulness:  1.0, affection:  0.0, temperament:  0.0, curiosity:  2.5, confidence:  0.5 }
  }.freeze

  # Exceptions for energy logic
  class PetSleepingError < StandardError; end
  class NotEnoughEnergyError < StandardError; end

  # ----------------------------------------
  # PUBLIC: Deduct `amount` from energy, after catching up.
  # Raises PetSleepingError if still asleep, or NotEnoughEnergyError if energy < amount.
  # If energy after deduction ≤ 10, sets asleep_until.
  # Does not save; caller should call save! afterwards.
  # ----------------------------------------
  def deduct_energy!(amount)
    catch_up_energy!
  
    if asleep_until.present? && Time.current < asleep_until
      remaining_minutes = ((asleep_until - Time.current) / 60).ceil
      raise PetSleepingError, "#{pet.name} is asleep for another #{remaining_minutes} minute#{'s' if remaining_minutes != 1}."
    end
  
    unless energy.to_i >= amount
      raise NotEnoughEnergyError, "#{pet.name} doesn’t have enough energy to interact."
    end
  
    # if we were at full energy, start the regen timer now
    was_full = energy.to_i >= MAX_ENERGY
  
    self.energy -= amount
    self.last_energy_update_at = Time.current if was_full
  
    if energy <= 10
      self.asleep_until = Time.current + sleep_duration
    end
  end

  def spend_energy!(amount)
    if asleep_until.present? && Time.current < asleep_until
      remaining_minutes = ((asleep_until - Time.current) / 60).ceil
      raise PetSleepingError, "#{pet.name} is asleep for another #{remaining_minutes} minute#{'s' if remaining_minutes != 1}."
    end

    unless energy.to_i >= amount
      raise NotEnoughEnergyError, "#{pet.name} doesn’t have enough energy to interact."
    end

    # If energy was full, start the regen timer now
    self.last_energy_update_at = Time.current if energy.to_i >= MAX_ENERGY

    self.energy -= amount

    if energy <= 10
      self.asleep_until = Time.current + sleep_duration
    end
  end


  def seconds_until_next_energy
    last = last_energy_update_at || created_at
    elapsed = Time.current.to_i - last.to_i
    remainder = ENERGY_INTERVAL - (elapsed % ENERGY_INTERVAL)
    remainder = ENERGY_INTERVAL if remainder.zero?
    remainder
  end

  # ----------------------------------------
  # PUBLIC: “Catch up” energy by granting +1 per ENERGY_INTERVAL since last_energy_update_at (or created_at).
  # Updates energy (capped at MAX_ENERGY) and advances last_energy_update_at to carry over leftover.
  # ----------------------------------------
  def catch_up_energy!
    now  = Time.current
    last = last_energy_update_at || created_at

    elapsed_seconds = now.to_i - last.to_i
    ticks = (elapsed_seconds / ENERGY_INTERVAL).floor
    return if ticks <= 0

    new_energy = [energy.to_i + ticks, MAX_ENERGY].min
    leftover_seconds = elapsed_seconds - (ticks * ENERGY_INTERVAL)

    update!(
      energy:                 new_energy,
      last_energy_update_at:  now - leftover_seconds
    )
  end

  # ----------------------------------------
  # PUBLIC: Duration to sleep when energy falls to 10 or below.
  # Base 2 hours minus (playfulness × 10 minutes), minimum 30 minutes.
  # ----------------------------------------
  def sleep_duration
    base      = 2.hours
    reduction = (playfulness.to_i * 10).minutes
    [base - reduction, 30.minutes].max
  end

  # ----------------------------------------
  # PUBLIC: Returns true if the pet has interactions_remaining > 0 and level < LEVEL_CAP.
  # ----------------------------------------
  def can_interact?
    interactions_remaining.to_i > 0 && level.to_i < LEVEL_CAP
  end

  # ----------------------------------------
  # PUBLIC: Returns true if the pet has enough EXP to level up and isn’t at LEVEL_CAP.
  # ----------------------------------------
  def can_level_up?
    exp.to_i >= EXP_PER_LEVEL && level.to_i < LEVEL_CAP
  end

  # ----------------------------------------
  # PUBLIC: Perform level up: subtract EXP_PER_LEVEL from exp, increment level,
  # reset interactions_remaining to 5, assign a random new pet_thought.
  # ----------------------------------------
  def level_up!
    return unless can_level_up?

    self.exp                = exp.to_i - EXP_PER_LEVEL
    self.level              = level.to_i + 1
    self.interactions_remaining = 5
    self.pet_thought        = PetThought.order("RANDOM()").first
    save!
  end

  # ----------------------------------------
  # Applies an interaction’s base impacts, modified by the pet’s current thought.
  # Decrements interactions_remaining by one. Saves the record.
  # ----------------------------------------
  def apply_interaction(interaction_type)
    return unless pet_thought && BASE_IMPACTS.key?(interaction_type)

    thought = pet_thought
    base    = BASE_IMPACTS[interaction_type]

    # Compute deltas for all five stats
    deltas = {
      playfulness:  base[:playfulness] * thought.playfulness_mod,
      affection:    base[:affection]   * thought.affection_mod,
      temperament:  base[:temperament] * thought.temperament_mod,
      curiosity:    base[:curiosity]   * thought.curiosity_mod,
      confidence:   base[:confidence]  * thought.confidence_mod
    }

    # Apply deltas
    deltas.each do |stat_name, change_value|
      current = send(stat_name) || 0
      write_attribute(stat_name, current + change_value)
    end

    # Decrement remaining interactions
    self.interactions_remaining = interactions_remaining.to_i - 1

    save!
  end
end
