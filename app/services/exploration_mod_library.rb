module ExplorationModLibrary
  CONFIG_PATH = Rails.root.join("config", "exploration_mods.yml")

  class << self
    def config
      @config ||= load_config
    end

    def bases
      config.fetch(:bases, {})
    end

    def prefixes
      config.fetch(:prefixes, {})
    end

    def suffixes
      config.fetch(:suffixes, {})
    end

    def sample_base(player_level: nil)
      weighted_sample(bases, player_level: player_level)
    end

    def sample_prefix(player_level: nil)
      weighted_sample(prefixes, player_level: player_level)
    end

    def sample_suffix(player_level: nil)
      weighted_sample(suffixes, player_level: player_level)
    end

    def rarity_palette
      config.fetch(:rarity_palette, {}).with_indifferent_access
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
      combos = config.fetch(:combinations, {}).with_indifferent_access
      search_keys = combination_keys(prefix_key, base_key, suffix_key)
      search_keys.each do |key|
        next if key.blank?
        return [key, combos[key]] if combos[key]
      end
      [nil, nil]
    end

    def reset!
      @config = nil
    end

    private

    def load_config
      if CONFIG_PATH.exist?
        raw = YAML.load_file(CONFIG_PATH)
        raw.respond_to?(:with_indifferent_access) ? raw.with_indifferent_access : raw
      else
        {}.with_indifferent_access
      end
    end

    def weighted_sample(entries, player_level: nil)
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
