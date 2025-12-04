class CareItemCatalog
  CONFIG_PATH = Rails.root.join("config", "care_items.yml")

  Entry = Struct.new(:key, :item_type, :name, :stats, :badge, :coin_buff, keyword_init: true)

  def self.for_interaction(interaction)
    new.for_interaction(interaction)
  end

  def for_interaction(interaction)
    data = config[interaction.to_s] || {}
    data.map do |key, value|
      normalized = normalize_entry(key, value)
      normalized if normalized
    end.compact
  end

  def config
    @config ||= if CONFIG_PATH.exist?
                  YAML.load_file(CONFIG_PATH).with_indifferent_access
                else
                  {}.with_indifferent_access
                end
  end

  private

  def normalize_entry(key, value)
    hash = value.is_a?(Hash) ? value.with_indifferent_access : {}
    item_type = hash[:item_type].presence || key.to_s
    name      = hash[:name].presence || key.to_s.humanize
    stats     = hash[:stats].presence || {}
    badge     = hash[:badge].presence
    coin_buff = normalize_coin_buff(hash[:coin_buff])

    Entry.new(
      key: key.to_s,
      item_type: item_type,
      name: name,
      stats: stats.transform_keys(&:to_sym),
      badge: badge,
      coin_buff: coin_buff
    )
  end

  def normalize_coin_buff(data)
    return nil unless data.present?
    hash = data.is_a?(Hash) ? data.with_indifferent_access : {}
    multiplier = hash[:multiplier].to_f
    duration   = hash[:duration_minutes].to_i
    return nil if multiplier.zero? || duration <= 0

    { multiplier: multiplier, duration_minutes: duration }
  end
end
