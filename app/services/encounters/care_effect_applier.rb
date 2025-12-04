module Encounters
  class CareEffectApplier
    class << self
      def apply!(user_exploration:, encounter_slug:, outcome_key:)
        effects = care_effects_for(encounter_slug, outcome_key)
        return [] if effects.blank?

        pets = Array(user_exploration.user_pets)
        pets.each do |pet|
          pet.apply_care_effects!(effects)
        end
        pets
      end

      def care_effects_for(encounter_slug, outcome_key)
        config = outcome_config(encounter_slug, outcome_key)
        return {} unless config

        raw = config["care_effects"] || config[:care_effects]
        normalize_effects(raw)
      end

      private

      def outcome_config(encounter_slug, outcome_key)
        entry = ExplorationEncounterStore.find(encounter_slug)&.data
        return nil unless entry

        rewards = entry["rewards"] || {}
        outcomes = rewards["outcomes"]
        outcome_hash = outcomes.respond_to?(:with_indifferent_access) ? outcomes.with_indifferent_access : outcomes
        outcome_hash&.[](outcome_key.to_s) || outcome_hash&.[](outcome_key&.to_sym)
      end

      def normalize_effects(raw)
        return {} unless raw

        raw.each_with_object({}) do |(key, value), memo|
          next if value.nil?
          memo[key.to_sym] = value.to_f
        end
      end
    end
  end
end
