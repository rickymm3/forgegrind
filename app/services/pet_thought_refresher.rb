# frozen_string_literal: true

class PetThoughtRefresher
  SUPPRESSION_CHANCE = 0.2

  def self.refresh!(pets, reference_time: Time.current)
    thoughts = PetThought.all.to_a
    Array(pets).compact.each do |pet|
      new(pet, reference_time: reference_time, thoughts: thoughts).refresh!
    end
  end

  def initialize(user_pet, reference_time: Time.current, thoughts: nil)
    @user_pet = user_pet
    @reference_time = reference_time || Time.current
    @thoughts = thoughts
  end

  def refresh!
    return unless user_pet
    return unless needs_refresh?

    assign_next_state!
  end

  private

  attr_reader :user_pet, :reference_time

  def needs_refresh?
    expires_at = user_pet.thought_expires_at
    return true if expires_at.blank?

    expires_at <= reference_time
  end

  def assign_next_state!
    attributes = {
      thought_expires_at: next_expiry
    }

    next_thought = roll_next_thought

    if next_thought
      attributes[:pet_thought] = next_thought
      attributes[:thought_suppressed] = false
    else
      attributes[:pet_thought] = nil
      attributes[:thought_suppressed] = true
    end

    user_pet.update!(attributes)
  end

  def next_expiry
    duration_hours = UserPet::THOUGHT_DURATION_RANGE.to_a.sample
    reference_time + duration_hours.hours
  end

  def roll_next_thought
    return nil if rand < SUPPRESSION_CHANCE

    thoughts = available_thoughts
    return nil if thoughts.empty?

    thoughts.sample
  end

  def available_thoughts
    @thoughts ||= PetThought.all.to_a
  end
end
