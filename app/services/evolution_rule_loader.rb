class EvolutionRuleLoader
  CONFIG_PATH = Rails.root.join("config", "evolution_rules.yml")

  RuleResult = Struct.new(:rule, :created)

  class << self
    def sync!(logger: Rails.logger)
      return unless CONFIG_PATH.exist?

      config = YAML.load_file(CONFIG_PATH)
      return unless config.is_a?(Hash)

      config.each do |identifier, payload|
        payload = (payload || {}).with_indifferent_access
        parent_name = payload[:parent] || identifier.to_s.humanize
        parent_pet  = Pet.find_by(name: parent_name)

        unless parent_pet
          logger.warn("[EvolutionRuleLoader] Parent pet '#{parent_name}' not found for #{identifier}")
          next
        end

        rules_hash = payload[:rules]
        unless rules_hash.is_a?(Hash)
          logger.warn("[EvolutionRuleLoader] No rules defined for #{parent_name}")
          next
        end

        rules_hash.each do |rule_key, rule_config|
          rule_config = (rule_config || {}).with_indifferent_access
          child_pet   = Pet.find_by(name: rule_config[:child])

          unless child_pet
            logger.warn("[EvolutionRuleLoader] Child pet '#{rule_config[:child]}' missing for rule #{rule_key}")
            next
          end

          lookup = {
            parent_pet: parent_pet,
            child_pet:  child_pet
          }
          lookup[:trigger_level]   = rule_config[:trigger_level] if rule_config.key?(:trigger_level)
          lookup[:window_min_level] = rule_config[:window_min_level] if rule_config.key?(:window_min_level)
          lookup[:window_max_level] = rule_config[:window_max_level] if rule_config.key?(:window_max_level)
          lookup[:window_event]     = rule_config[:window_event] if rule_config.key?(:window_event)

          rule = EvolutionRule.find_or_initialize_by(lookup)
          created = rule.new_record?
          rule.priority     = rule_config[:priority] if rule_config.key?(:priority)
          rule.one_shot     = rule_config[:one_shot] unless rule_config[:one_shot].nil?
          rule.seasonal_tag = rule_config[:seasonal_tag]
          rule.notes        = rule_config[:notes]
          rule.guard_json   = prepare_guard(rule_config[:guard])

          rule.save!
          logger.info("[EvolutionRuleLoader] #{created ? 'Created' : 'Updated'} rule #{rule_key} #{parent_pet.name} -> #{child_pet.name}") if logger
        end
      end
    end

    private

    def prepare_guard(value)
      guard = (value || {})
      guard = guard.respond_to?(:deep_stringify_keys) ? guard.deep_stringify_keys : guard
      guard
    end
  end
end
