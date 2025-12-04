module ExplorationModLibrary
  CONFIG_PATH = Rails.root.join("config", "exploration_mods.yml")
  EXPLORATIONS_DIR = Rails.root.join("config", "explorations")
  BASES_PATH = EXPLORATIONS_DIR.join("bases.yml")
  AFFIXES_PATH = EXPLORATIONS_DIR.join("affixes.yml")
  SUFFIXES_PATH = EXPLORATIONS_DIR.join("suffixes.yml")
  COMBINATIONS_PATH = EXPLORATIONS_DIR.join("combinations.yml")
  RARITIES_PATH = EXPLORATIONS_DIR.join("rarities.yml")

  class << self
    def config
      @config ||= load_config
    end

    def bases
      @bases ||= load_new_entries(BASES_PATH, :bases) || config.fetch(:bases, {})
    end

    def prefixes
      @prefixes ||= load_new_entries(AFFIXES_PATH, :affixes, :prefix) || config.fetch(:prefixes, {})
    end

    def suffixes
      @suffixes ||= load_new_entries(SUFFIXES_PATH, :suffixes, :suffix) || config.fetch(:suffixes, {})
    end

    def sample_base(player_level: nil)
      weighted_sample(bases, player_level: player_level)
    end

    def sample_prefix(player_level: nil, world_key: nil)
      weighted_sample(prefixes, player_level: player_level, world_key: world_key)
    end

    def sample_suffix(player_level: nil, world_key: nil)
      weighted_sample(suffixes, player_level: player_level, world_key: world_key)
    end

    def rarity_palette
      @rarity_palette ||= begin
        if RARITIES_PATH.exist?
          data = load_yaml_file(RARITIES_PATH)
          (data[:rarities] || data["rarities"] || {}).with_indifferent_access
        else
          config.fetch(:rarity_palette, {}).with_indifferent_access
        end
      end
    end

    def base_mods
      bases
    end

    def prefix_mods
      prefixes
    end

    def suffix_mods
      suffixes
    end

    def combination(prefix_key, base_key, suffix_key = nil)
      combos = combination_entries
      search_keys = combination_keys(prefix_key, base_key, suffix_key)
      search_keys.each do |key|
        next if key.blank?
        return [key, combos[key]] if combos[key]
      end
      [nil, nil]
    end

    def reset!
      @config = nil
      @bases = nil
      @prefixes = nil
      @suffixes = nil
      @combinations = nil
      @rarity_palette = nil
    end

    private

    def combination_entries
      @combinations ||= begin
        if COMBINATIONS_PATH.exist?
          data = load_yaml_file(COMBINATIONS_PATH)
          entries = data[:combinations] || data["combinations"] || {}
          entries.with_indifferent_access
        else
          config.fetch(:combinations, {}).with_indifferent_access
        end
      end
    end

    def load_new_entries(path, root_key, type = nil)
      return unless path.exist?

      data = load_yaml_file(path)
      collection = data[root_key] || data[root_key.to_s]
      return if collection.blank?

      normalized = collection.each_with_object({}.with_indifferent_access) do |(key, value), memo|
        memo[key] = normalize_entry(value, type)
      end

      normalized
    rescue Psych::SyntaxError => e
      Rails.logger.error("Failed to load #{path}: #{e.message}")
      nil
    end

    def normalize_entry(entry, type)
      hash = entry.respond_to?(:with_indifferent_access) ? entry.with_indifferent_access : entry
      case type
      when :prefix
        normalize_modifier_entry(hash)
      when :suffix
        normalize_modifier_entry(hash)
      else
        normalize_base_entry(hash)
      end
    end

    def normalize_base_entry(entry)
      normalized = entry.deep_dup.with_indifferent_access
      normalized[:segments] ||= build_segments_from_labels(normalized[:checkpoint_labels], :base_checkpoint)
      normalized[:requirements] ||= []
      normalized[:rewards] ||= {}
      normalized[:world_key] ||= normalized[:world_name]&.parameterize&.underscore
      normalized[:world_key] ||= normalized[:label]&.parameterize&.underscore
      normalized
    end

    def normalize_modifier_entry(entry)
      normalized = entry.deep_dup.with_indifferent_access

      duration = normalized.delete(:duration)
      if duration.present?
        normalized[:duration_multiplier] ||= duration[:multiplier] if duration[:multiplier]
        normalized[:duration_bonus] ||= duration[:bonus] if duration[:bonus]
      end

      normalized[:rewards] ||= normalized[:reward_modifiers] if normalized[:reward_modifiers].present?
      normalized[:segments] ||= build_segments_from_labels(normalized[:checkpoint_labels], :modifier_checkpoint)
      normalized[:applies_to] = normalize_applies_to(normalized[:applies_to])
      normalized[:requirements] ||= []
      normalized
    end

    def build_segments_from_labels(labels, source_prefix)
      Array(labels).each_with_index.map do |label, index|
        next if label.blank?

        {
          key: "#{source_prefix}_#{index + 1}",
          label: label,
          duration_weight: 1,
          source: source_prefix
        }
      end.compact
    end

    def normalize_applies_to(values)
      list = Array(values).map(&:to_s).reject(&:blank?)
      list.presence || ["global"]
    end

    def load_config
      if CONFIG_PATH.exist?
        load_yaml_file(CONFIG_PATH)
      else
        {}.with_indifferent_access
      end
    end

    def load_yaml_file(path)
      raw = YAML.load_file(path)
      raw.respond_to?(:with_indifferent_access) ? raw.with_indifferent_access : raw
    end

    def weighted_sample(entries, player_level: nil, world_key: nil)
      return entries.first if entries.is_a?(Array)
      return [nil, {}] if entries.blank?

      rows = entries.map do |key, value|
        weight = value[:weight].presence || value['weight'].presence || 1
        config_value = value.respond_to?(:with_indifferent_access) ? value.with_indifferent_access : value
        [key, config_value, weight.to_f]
      end

      if player_level
        eligible = rows.select { |(_, config_value, _)| allowed_for_player_level?(config_value, player_level) }
        rows = eligible if eligible.any?
      end

      if world_key.present?
        eligible = rows.select { |(_, config_value, _)| allowed_for_world?(config_value, world_key) }
        rows = eligible if eligible.any?
      end

      total = rows.sum { |(_, _, weight)| weight }
      target = rand * total
      running = 0.0

      rows.each do |key, value, weight|
        running += weight
        return [key.to_s, value] if target <= running
      end

      last = rows.last
      [last[0].to_s, last[1]]
    end

    def allowed_for_player_level?(config, player_level)
      level = player_level.to_i
      min = config[:player_level_min] || config['player_level_min'] || 1
      max = config[:player_level_max] || config['player_level_max']
      return false if level < min.to_i
      return false if max.present? && level > max.to_i
      true
    end

    def allowed_for_world?(config, world_key)
      applies = Array(config[:applies_to] || config['applies_to']).map(&:to_s)
      return true if applies.blank?

      world = world_key.to_s
      applies.include?('global') || applies.include?(world)
    end

    def combination_keys(prefix_key, base_key, suffix_key)
      prefix = sanitize_key(prefix_key)
      base   = sanitize_key(base_key)
      suffix = sanitize_key(suffix_key)

      combos = []
      combos << [prefix, base, suffix]
      combos << [prefix, base]
      combos << [base, suffix]
      combos << [base]

      combos.map do |parts|
        filtered = parts.compact
        filtered.join('+')
      end.uniq
    end

    def sanitize_key(key)
      return nil if key.blank?
      value = key.to_s
      return nil if value == "none"
      value
    end
  end
end
