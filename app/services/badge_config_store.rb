class BadgeConfigStore
  CONFIG_PATH = BadgeRegistry::CONFIG_PATH

  def self.load_config
    if CONFIG_PATH.exist?
      YAML.load_file(CONFIG_PATH) || {}
    else
      {}
    end
  end

  def self.badges
    load_config.fetch("badges", {}) || {}
  end

  def self.find(key)
    badges[key.to_s]
  end

  def self.upsert!(key, payload)
    config = load_config
    config["badges"] ||= {}
    config["badges"][key.to_s] = payload
    write_config!(config)
  end

  def self.delete!(key)
    config = load_config
    return unless config["badges"]

    removed = config["badges"].delete(key.to_s)
    write_config!(config) if removed
  end

  def self.write_config!(config)
    File.write(CONFIG_PATH, config.to_yaml)
    BadgeRegistry.reset!
  end
end
