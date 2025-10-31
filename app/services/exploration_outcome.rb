class ExplorationOutcome
  Result = Struct.new(
    :reward_multiplier,
    :diamond_multiplier,
    :need_penalty_multiplier,
    keyword_init: true
  )

  MIN_MULTIPLIER = 0.0

  class << self
    def evaluate(world:, user_pets:)
      user_pets = Array(user_pets).compact
      return default_result if user_pets.empty?

      level_factor      = average_level_factor(user_pets)
      element_factor    = element_match_factor(world, user_pets)
      duration_factor   = duration_factor(world)

      reward_multiplier  = 1.0 + (element_factor * 0.35) + (level_factor * 0.25) + (duration_factor * 0.1)
      diamond_multiplier = 1.0 + (element_factor * 0.25) + (duration_factor * 0.15)

      penalty_multiplier = (1.0 + duration_factor * 0.25) * (1.0 - element_factor * 0.4)
      penalty_multiplier = penalty_multiplier.clamp(0.5, 1.6)

      Result.new(
        reward_multiplier:  reward_multiplier,
        diamond_multiplier: diamond_multiplier,
        need_penalty_multiplier: penalty_multiplier
      )
    end

    private

    def default_result
      Result.new(
        reward_multiplier: 1.0,
        diamond_multiplier: 1.0,
        need_penalty_multiplier: 1.0
      )
    end

    def average_level_factor(user_pets)
      avg_level = user_pets.sum { |up| up.level.to_f } / user_pets.size
      (avg_level / UserPet::LEVEL_CAP).clamp(0.0, 1.0)
    rescue ZeroDivisionError
      0.0
    end

    def element_match_factor(world, user_pets)
      world_types = world.pet_types.to_a
      return 0.0 if world_types.empty?

      world_type_ids = world_types.map(&:id)
      total_possible = world_types.size * user_pets.size
      return 0.0 if total_possible.zero?

      matches = user_pets.sum do |user_pet|
        user_pet.pet.pet_types.where(id: world_type_ids).count
      end

      (matches.to_f / total_possible).clamp(0.0, 1.0)
    end

    def duration_factor(world)
      duration_minutes = world.duration.to_i / 60.0
      normalized = duration_minutes / 15.0 # every 15 minutes increases difficulty
      normalized.clamp(0.0, 3.0)
    end
  end
end
