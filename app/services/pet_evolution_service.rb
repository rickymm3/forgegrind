class PetEvolutionService
  class << self
    # Returns all EvolutionRule records applicable to this UserPet
    def applicable_rules(user_pet)
      EvolutionRule
        .where(parent_pet_id: user_pet.pet_id)
        .select { |rule| rule.matches?(user_pet) }
    end

    # Perform the evolution flow. Retires the predecessor, creates a successor linked via
    # predecessor/successor pointers, updates journal history, and copies abilities.
    # Returns the newly created successor UserPet.
    def evolve!(predecessor, rule:, child_pet:, timestamp: Time.current, misses: [])
      timestamp ||= Time.current
      successor = nil

      UserPet.transaction do
        successor = build_successor_user_pet(predecessor: predecessor, child_pet: child_pet, timestamp: timestamp)
        copy_abilities(predecessor: predecessor, successor: successor)

        journal = updated_journal(predecessor: predecessor, child_pet: child_pet, rule: rule, timestamp: timestamp, misses: misses)
        successor_journal = journal.deep_dup

        predecessor.user_explorations.clear
        predecessor.battle_sessions.clear

        successor_badges = transfer_badges(predecessor)
        successor_flags = successor.state_flags.deep_dup
        successor_flags["evolved_from_user_pet_id"] = predecessor.id
        successor_flags["evolved_from_pet_id"]      = predecessor.pet_id
        successor_flags["evolved_from_at"]          = timestamp.iso8601

        successor.update!(
          predecessor_user_pet: predecessor,
          state_flags: successor_flags,
          badges: successor_badges,
          evolution_journal: successor_journal
        )

        predecessor_flags = predecessor.state_flags.deep_dup
        predecessor_flags["evolved"]                = true
        predecessor_flags["evolved_at"]             = timestamp.iso8601
        predecessor_flags["evolved_to_user_pet_id"] = successor.id
        predecessor_flags["evolved_to_pet_id"]      = child_pet.id

        predecessor_badges = prune_non_transferable_badges(predecessor)
        predecessor.update!(
          retired_at:          timestamp,
          retired_reason:      "evolved",
          successor_user_pet:  successor,
          held_user_item:      nil,
          evolution_journal:   journal,
          exp:                 0,
          equipped:            false,
          badges:              predecessor_badges,
          state_flags:         predecessor_flags
        )
      end

      successor
    end

    private

    def build_successor_user_pet(predecessor:, child_pet:, timestamp:)
      thought = predecessor.pet_thought || PetThought.order("RANDOM()").first

      predecessor_default_name = predecessor.pet.name
      successor_name = if predecessor.name.present? && predecessor.name != predecessor_default_name
                         predecessor.name
                       else
                         child_pet.name
                       end

      successor = predecessor.user.user_pets.build(
        pet:                    child_pet,
        egg:                    child_pet.egg || predecessor.egg,
        name:                   successor_name,
        rarity:                 child_pet.rarity || predecessor.rarity,
        power:                  child_pet.power,
        pet_thought:            thought,
        playfulness:            predecessor.playfulness,
        affection:              predecessor.affection,
        temperament:            predecessor.temperament,
        curiosity:              predecessor.curiosity,
        confidence:             predecessor.confidence,
        level:                  predecessor.level,
        exp:                    predecessor.exp,
        interactions_remaining: predecessor.interactions_remaining,
        energy:                 predecessor.energy,
        asleep_until:           predecessor.asleep_until,
        last_interacted_at:     predecessor.last_interacted_at,
        last_energy_update_at:  predecessor.last_energy_update_at || timestamp,
        hunger:                 predecessor.hunger,
        hygiene:                predecessor.hygiene,
        boredom:                predecessor.boredom,
        injury_level:           predecessor.injury_level,
        mood:                   predecessor.mood,
        needs_updated_at:       predecessor.needs_updated_at || timestamp,
        care_trackers:          predecessor.care_trackers
      )

      successor.skip_default_ability = true
      successor.save!
      successor
    end

    def copy_abilities(predecessor:, successor:)
      predecessor.user_pet_abilities.find_each do |user_pet_ability|
        successor.user_pet_abilities.create!(
          ability:      user_pet_ability.ability,
          unlocked_via: user_pet_ability.unlocked_via
        )
      end
    end

    def updated_journal(predecessor:, child_pet:, rule:, timestamp:, misses:)
      journal = predecessor.evolution_journal.deep_dup
      journal["history"] ||= []
      journal["misses"]  ||= {}

      journal["history"] << {
        "at"        => timestamp.iso8601,
        "parent_id" => predecessor.pet_id,
        "child_id"  => child_pet.id,
        "rule_id"   => rule.id
      }

      Array(misses).each { |key| journal["misses"].delete(key) }
      journal
    end

    def transfer_badges(predecessor)
      return [] unless predecessor.badges.present?

      transferable = predecessor.badges.select do |badge_key|
        definition = BadgeRegistry.find(badge_key)
        definition&.transfers_on_level_up
      end

      transferable
    end

    def prune_non_transferable_badges(predecessor)
      return [] unless predecessor.badges.present?

      predecessor.badges.select do |badge_key|
        definition = BadgeRegistry.find(badge_key)
        definition&.transfers_on_level_up
      end
    end
  end
end
