# frozen_string_literal: true

class BadgeEngine
  GuardEvaluator = Struct.new(:user_pet, :tracker_snapshot, keyword_init: true) do
    def satisfied?(conditions)
      conditions ||= {}
      all_conditions = Array(conditions["all"])
      any_conditions = Array(conditions["any"])

      all_pass = all_conditions.all? { |condition| evaluate_condition(condition) }
      any_pass = any_conditions.empty? || any_conditions.any? { |condition| evaluate_condition(condition) }

      all_pass && any_pass
    end

    private

    def evaluate_condition(condition)
      return true unless condition.is_a?(Hash)

      type = condition["type"]&.to_s
      key  = condition["key"]
      value = condition["value"]

      case type
      when "tracker_at_least"
        tracker_value(key) >= value.to_i
      when "tracker_at_most"
        tracker_value(key) <= value.to_i
      when "trait_at_least"
        attribute_value(key) >= value.to_f
      when "trait_at_most"
        attribute_value(key) <= value.to_f
      when "need_at_least"
        need_value(key) >= value.to_f
      when "need_at_most"
        need_value(key) <= value.to_f
      when "flag_true"
        user_pet.flag?(key)
      when "flag_false"
        !user_pet.flag?(key)
      when "item_held"
        item_held?(value || key)
      else
        Rails.logger.info("[BadgeEngine] Unknown condition type: #{type.inspect}") if defined?(Rails)
        false
      end
    end

    def tracker_value(key)
      tracker_snapshot.fetch(key.to_s, user_pet.care_tracker_value(key))
    end

    def attribute_value(key)
      user_pet.respond_to?(key) ? user_pet.send(key).to_f : 0.0
    end

    def need_value(key)
      attribute_value(key)
    end

    def item_held?(item_identifier)
      return false unless item_identifier.present?

      item = case item_identifier
             when Integer
               Item.find_by(id: item_identifier)
             else
               Item.find_by(name: item_identifier) || Item.find_by(item_type: item_identifier)
             end

      return false unless item

      user_pet.user.user_items.exists?(item_id: item.id)
    end
  end

  def initialize(user_pet, tracker_snapshot: nil)
    @user_pet = user_pet
    @tracker_snapshot = tracker_snapshot || default_tracker_snapshot
    @evaluator = GuardEvaluator.new(user_pet: user_pet, tracker_snapshot: @tracker_snapshot)
  end

  def evaluate!
    definitions = BadgeRegistry.definitions
    return { gained: [], removed: [] } if definitions.empty?

    current_badges = user_pet.badges.map(&:to_s)
    gained = []
    removed = []

    definitions.each_value do |definition|
      meets_requirements = evaluator.satisfied?(definition.conditions)

      if meets_requirements
        unless current_badges.include?(definition.key)
          gained << definition.key
        end

        Array(definition.overrides["remove"]).each do |badge_to_remove|
          next if badge_to_remove == definition.key
          removed << badge_to_remove.to_s if current_badges.include?(badge_to_remove.to_s)
        end
      end
    end

    { gained: gained.uniq, removed: removed.uniq }
  end

  private

  attr_reader :user_pet, :tracker_snapshot, :evaluator

  def default_tracker_snapshot
    {
      "hunger_score" => user_pet.care_tracker_value(:hunger_score),
      "hygiene_score" => user_pet.care_tracker_value(:hygiene_score),
      "boredom_score" => user_pet.care_tracker_value(:boredom_score),
      "injury_score" => user_pet.care_tracker_value(:injury_score),
      "mood_score" => user_pet.care_tracker_value(:mood_score)
    }
  end
end
