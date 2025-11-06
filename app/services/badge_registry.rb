# frozen_string_literal: true

class BadgeRegistry
  CONFIG_PATH = Rails.root.join("config", "badges.yml")

  BadgeDefinition = Struct.new(
    :key,
    :label,
    :description,
    :color,
    :conditions,
    :transfers_on_level_up,
    :overrides,
    keyword_init: true
  )

  class << self
    def definitions
      @definitions ||= load_definitions
    end

    def find(key)
      definitions[key.to_s]
    end

    private

    def load_definitions
      return {} unless CONFIG_PATH.exist?

      config = YAML.load_file(CONFIG_PATH)
      raw_badges = config["badges"] || {}

      raw_badges.each_with_object({}) do |(key, payload), memo|
        payload = payload || {}
        memo[key.to_s] = BadgeDefinition.new(
          key: key.to_s,
          label: payload["label"] || key.to_s.humanize,
          description: payload["description"],
          color: payload["color"],
          conditions: payload["conditions"] || {},
          transfers_on_level_up: payload.fetch("transfers_on_level_up", false),
          overrides: payload["overrides"] || {}
        )
      end
    end
  end
end
