module Encounters
  class ChanceCalculator
    DEFAULT_BASE = 0.65
    REQUIREMENT_BONUS = 0.05
    ABILITY_REF_BONUS = 0.12
    ABILITY_TAG_BONUS = 0.08
    MIN_CHANCE = 0.15
    MAX_CHANCE = 0.95

    def initialize(user_exploration, option)
      @user_exploration = user_exploration
      @option = option.respond_to?(:with_indifferent_access) ? option.with_indifferent_access : option
    end

    def chance_data
      chance = base_chance
      breakdown = []

      req_bonus = requirement_bonus
      if req_bonus.positive?
        chance += req_bonus
        breakdown << { type: :requirements, amount: req_bonus }
      end

      ability_bonus = ability_requirement_bonus
      if ability_bonus.positive?
        chance += ability_bonus
        breakdown << { type: :ability_synergy, amount: ability_bonus }
      end

      chance = chance.clamp(MIN_CHANCE, MAX_CHANCE)
      { chance: chance, breakdown: breakdown }
    end

    private

    attr_reader :user_exploration, :option

    def base_chance
      if option[:success].is_a?(Hash)
        success_config = option[:success].with_indifferent_access
        explicit = success_config[:chance].presence || success_config[:base]
        return explicit.to_f if explicit.present?
      end

      explicit = option[:success_chance]
      return explicit.to_f if explicit.present?

      DEFAULT_BASE
    end

    def requirement_bonus
      fulfilled = user_exploration.respond_to?(:fulfilled_party_requirements_count) ? user_exploration.fulfilled_party_requirements_count : 0
      fulfilled * REQUIREMENT_BONUS
    end

    def ability_requirement_bonus
      requirements = option[:requires]
      return 0.0 if requirements.blank?

      requirements = requirements.with_indifferent_access if requirements.respond_to?(:with_indifferent_access)

      bonus = 0.0

      refs = Array(requirements[:special_abilities]).map(&:to_s).reject(&:blank?)
      tags = Array(requirements[:special_ability_tags]).map(&:to_s).reject(&:blank?)

      if refs.any?
        member_refs = Array(user_exploration.party_ability_refs).map(&:to_s)
        bonus += ABILITY_REF_BONUS if (member_refs & refs).any?
      end

      if tags.any?
        member_tags = Array(user_exploration.party_ability_tags).map(&:to_s)
        bonus += ABILITY_TAG_BONUS if (member_tags & tags).any?
      end

      bonus
    end
  end
end
