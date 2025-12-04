class ExplorationEncounterStore
  CONFIG_PATH = Rails.root.join("config", "explorations", "encounters.yml")

  Entry = Struct.new(:slug, :data, keyword_init: true)

  class << self
    def all_entries
      encounters = load_encounters
      encounters.map { |entry| Entry.new(slug: entry["slug"], data: entry) }
                .sort_by(&:slug)
    end

    def find(slug)
      data = load_encounters.find { |entry| entry["slug"] == slug }
      data && Entry.new(slug: data["slug"], data: data)
    end

    def update!(slug:, attributes:)
      list = load_encounters
      index = list.index { |entry| entry["slug"] == slug }
      raise ArgumentError, "Encounter #{slug} was not found." unless index

      list[index] = attributes
      persist!(list)
    end

    def persist!(entries)
      payload = load_raw
      payload["encounters"] = entries
      File.write(CONFIG_PATH, payload.to_yaml)
      ExplorationEncounterCatalog.reload!
    end

    private

    def load_encounters
      Array(load_raw["encounters"]).map do |entry|
        entry.respond_to?(:deep_dup) ? entry.deep_dup : entry.dup
      end
    end

    def load_raw
      if CONFIG_PATH.exist?
        YAML.load_file(CONFIG_PATH) || {}
      else
        {}
      end
    rescue Psych::SyntaxError => e
      Rails.logger.error("Failed to parse #{CONFIG_PATH}: #{e.message}")
      {}
    end
  end
end
