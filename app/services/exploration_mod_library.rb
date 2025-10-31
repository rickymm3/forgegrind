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

    def sample_base
      weighted_sample(bases)
    end

    def sample_prefix
      weighted_sample(prefixes)
    end

    def sample_suffix
      weighted_sample(suffixes)
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

    def weighted_sample(entries)
      return entries.first if entries.is_a?(Array)
      return [nil, {}] if entries.blank?

      rows = entries.map do |key, value|
        weight = value[:weight].presence || value['weight'].presence || 1
        [key, value.with_indifferent_access, weight.to_f]
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
  end
end
