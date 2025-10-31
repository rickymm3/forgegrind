class EvolutionEngine
  Result = Struct.new(:evolved, :child_pet, :rule, :misses, keyword_init: true)

  def initialize(user_pet:)
    @user_pet = user_pet
  end

  def evaluate_on_level_up!
    evaluate(level: @user_pet.level)
  end

  def evaluate_on_event!(event_key:)
    evaluate(event: event_key)
  end

  # Public helper for admin dry-runs: simulate a specific level and/or event.
  def evaluate_for(level: nil, event: nil)
    evaluate(level: level, event: event)
  end

  private

  attr_reader :user_pet

  def evaluate(level: nil, event: nil)
    candidate_rules = rules_for(level: level, event: event)
    misses = []

    candidate_rules.each do |rule|
      if guard_satisfied?(rule)
        Rails.logger.info("[EvolutionEngine] Match rule=#{rule.id} parent=#{user_pet.pet_id} child=#{rule.child_pet_id} window=#{window_key(rule, level: level, event: event)}")
        return Result.new(
          evolved: true,
          child_pet: rule.child_pet,
          rule: rule,
          misses: misses
        )
      else
        wkey = window_key(rule, level: level, event: event)
        Rails.logger.info("[EvolutionEngine] Miss rule=#{rule.id} window=#{wkey}")
        misses << wkey
      end
    end

    misses << level_window_key(level) if misses.empty? && level.present?

    Result.new(evolved: false, child_pet: nil, rule: nil, misses: misses.compact.uniq)
  end

  def rules_for(level:, event:)
    base = EvolutionRule.where(parent_pet_id: user_pet.pet_id)

    filtered = base.select do |rule|
      next false if rule.one_shot? && rule_already_applied?(rule)

      if event.present?
        rule.window_event.present? && rule.window_event == event
      else
        window_matches_level?(rule, level)
      end
    end

    filtered.sort_by do |rule|
      [ -rule.priority.to_i,
        -specificity_score(rule),
        rule.id ]
    end
  end

  def guard_satisfied?(rule)
    guard = rule.guard_json.presence || {}
    all_conditions = Array(guard["all"])
    any_conditions = Array(guard["any"])

    all_pass = all_conditions.all? { |condition| condition_pass?(condition) }
    any_pass = any_conditions.empty? || any_conditions.any? { |condition| condition_pass?(condition) }

    all_pass && any_pass
  end

  def condition_pass?(condition)
    return true unless condition.is_a?(Hash)

    type = condition["type"]&.to_s
    key  = condition["key"] || condition["attr"] || condition["stat"]
    value = condition["value"]

    case type
    when "trait_at_least"
      attribute_at_least?(key, value)
    when "trait_at_most"
      attribute_at_most?(key, value)
    when "need_at_least"
      need_at_least?(key, value)
    when "need_at_most"
      need_at_most?(key, value)
    when "sum_traits_at_least"
      sum_at_least?(Array(condition["keys"]), value)
    when "sum_traits_at_most"
      sum_at_most?(Array(condition["keys"]), value)
    when "sum_needs_at_least"
      sum_at_least?(Array(condition["keys"]), value)
    when "sum_needs_at_most"
      sum_at_most?(Array(condition["keys"]), value)
    when "flag_true"
      user_pet.flag?(key)
    when "item_held"
      item_held?(value || key)
    when "season_is"
      season_matches?(value)
    when "explorations_at_least"
      explorations_count >= value.to_i
    when "plays_at_least"
      plays_count >= value.to_i
    else
      Rails.logger.info("[EvolutionEngine] Unknown guard type: #{type.inspect}")
      false
    end
  end

  def attribute_at_least?(attr, threshold)
    return false unless attr && threshold
    user_pet.send(attr).to_f >= threshold.to_f
  rescue NoMethodError
    false
  end

  def attribute_at_most?(attr, threshold)
    return false unless attr && threshold
    user_pet.send(attr).to_f <= threshold.to_f
  rescue NoMethodError
    false
  end

  def need_at_least?(attr, threshold)
    attribute_at_least?(attr, threshold)
  end

  def need_at_most?(attr, threshold)
    attribute_at_most?(attr, threshold)
  end

  def sum_at_least?(keys, threshold)
    return false if keys.blank? || threshold.nil?
    total = keys.sum { |k| safe_attribute(k) }
    total >= threshold.to_f
  end

  def sum_at_most?(keys, threshold)
    return false if keys.blank? || threshold.nil?
    total = keys.sum { |k| safe_attribute(k) }
    total <= threshold.to_f
  end

  def safe_attribute(attr)
    return 0.0 unless attr.present?
    user_pet.send(attr).to_f
  rescue NoMethodError
    0.0
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

  def season_matches?(expected)
    return false unless expected.present?
    current = GameConfig.respond_to?(:current_season) ? GameConfig.current_season : nil
    current.to_s.casecmp(expected.to_s).zero?
  end

  def explorations_count
    @explorations_count ||= UserExploration.joins(:user_pets)
                                           .where(user_pets: { id: user_pet.id })
                                           .count
  end

  def plays_count
    state_key = "plays_total"
    user_pet.state_flags[state_key].to_i
  end

  def rule_already_applied?(rule)
    history = user_pet.evolution_journal.fetch("history", [])
    history.any? { |entry| entry && entry["rule_id"] == rule.id }
  end

  def window_matches_level?(rule, level)
    level ||= user_pet.level

    if rule.trigger_level.present?
      level.to_i == rule.trigger_level.to_i
    else
      min_ok = rule.window_min_level.blank? || level.to_i >= rule.window_min_level.to_i
      max_ok = rule.window_max_level.blank? || level.to_i <= rule.window_max_level.to_i
      min_ok && max_ok
    end
  end

  def specificity_score(rule)
    if rule.trigger_level.present?
      3
    elsif rule.window_min_level.present? || rule.window_max_level.present?
      2
    elsif rule.window_event.present?
      2
    else
      1
    end
  end

  def window_key(rule, level: nil, event: nil)
    if rule.trigger_level.present?
      "L#{rule.trigger_level}"
    elsif rule.window_event.present?
      "event:#{rule.window_event}"
    elsif rule.window_min_level.present? || rule.window_max_level.present?
      min = rule.window_min_level || level
      max = rule.window_max_level || level
      "L#{min}-#{max}"
    elsif level.present?
      level_window_key(level)
    else
      "rule:#{rule.id}"
    end
  end

  def level_window_key(level)
    return nil unless level
    "L#{level}"
  end
end
