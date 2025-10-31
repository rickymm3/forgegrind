module ZoneTraitLibrary
  CONFIG_PATH = Rails.root.join("config", "zone_traits.yml")

  class << self
    def fetch(key)
      traits[key.to_s] || {}
    end

    def label_for(key)
      fetch(key)["label"] || key.to_s.humanize
    end

    def required_abilities_for(key)
      Array(fetch(key)["required_abilities"]).map(&:to_s)
    end

    def drop_table_key_for(key)
      fetch(key)["drop_table_override"]
    end

    def random_trait_keys(limit = 1)
      traits.keys.sample(limit)
    end

    def traits
      @traits ||= begin
        if CONFIG_PATH.exist?
          YAML.load_file(CONFIG_PATH).with_indifferent_access.fetch(:traits, {})
        else
          {}
        end
      end
    end
  end
end
