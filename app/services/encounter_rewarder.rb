class EncounterRewarder
  DEFAULT_ITEM_POOL = %w[
    treat
    frisbee
    blanket
    map
    soap
    whistle
    leveling_stone
    fire_stone
    water_stone
    grass_stone
    ice_stone
    wind_stone
  ].freeze

  class << self
    def award!(user_exploration:, encounter_slug:, outcome_key: nil)
      user = user_exploration&.user
      return nil unless user

      payload = award_from_drop_tables(
        user,
        encounter_slug: encounter_slug,
        outcome_key: outcome_key
      )
      payload ||= award_from_legacy_pool(
        user,
        encounter_slug: encounter_slug,
        outcome_key: outcome_key
      )
      return nil if payload.blank?

      summary_parts = []
      if payload[:items].present?
        summary_parts.concat(payload[:items].map { |entry| "#{entry[:name]} x#{entry[:quantity]}" })
      end
      if payload[:eggs].present?
        summary_parts.concat(payload[:eggs].map { |entry| entry[:name] })
      end
      return nil if summary_parts.empty?

      {
        rewards: payload,
        summary: summary_parts.join(", ")
      }
    rescue StandardError => e
      Rails.logger.debug do
        "[EncounterRewarder] Failed to award encounter rewards for exploration ##{user_exploration&.id}: #{e.message}"
      end
      nil
    end

    private

    def award_from_drop_tables(user, encounter_slug:, outcome_key:)
      drop_keys = reward_drop_keys_for(encounter_slug, outcome_key)
      return nil if drop_keys.blank?

      reward = ExplorationRewards.for_drop_keys(drop_keys)
      return nil unless reward

      items = award_items_from_config(user, reward.items)
      eggs = award_eggs_from_config(user, reward.eggs)

      return nil if items.blank? && eggs.blank?

      {
        items: items,
        eggs: eggs
      }
    end

    def award_from_legacy_pool(user, encounter_slug:, outcome_key:)
      items = award_items_from_pool(user, encounter_slug: encounter_slug, outcome_key: outcome_key)
      eggs = award_legacy_eggs(user, encounter_slug: encounter_slug)
      return nil if items.blank? && eggs.blank?

      {
        items: items,
        eggs: eggs
      }
    end

    def award_items_from_config(user, items_config)
      return [] if items_config.blank?

      drops = ExplorationRewards.resolve_item_drops(items_config)
      drops.map do |item_type, quantity|
        next if quantity.to_i <= 0

        user_item = ItemAwarder.award_specific(user, item_type, quantity)
        {
          item_type: item_type,
          quantity: quantity,
          name: user_item.item.name
        }
      rescue ActiveRecord::RecordNotFound => e
        Rails.logger.debug { "[EncounterRewarder] Missing configured item #{item_type}: #{e.message}" }
        nil
      end.compact
    end

    def award_items_from_pool(user, encounter_slug:, outcome_key:)
      pool = item_pool_for(encounter_slug, outcome_key)
      return [] if pool.blank?

      rng = Random.new
      count = 1 + rng.rand(0..1)

      Array.new(count).filter_map do
        item_type = pool.sample(random: rng)
        next unless item_type

        begin
          user_item = ItemAwarder.award_specific(user, item_type, 1)
          {
            item_type: item_type,
            quantity: 1,
            name: user_item.item.name
          }
        rescue ActiveRecord::RecordNotFound => e
          Rails.logger.debug { "[EncounterRewarder] Missing fallback item #{item_type}: #{e.message}" }
          nil
        end
      end
    end

    def award_eggs_from_config(user, eggs_config)
      return [] if eggs_config.blank?

      rng = Random.new
      eggs_config.each_value.with_object([]) do |definition, memo|
        entry = definition.with_indifferent_access
        quantity = entry[:quantity].to_i
        next if quantity <= 0

        chance = entry[:chance].to_f
        quantity.times do
          next unless chance >= 1.0 || rng.rand < chance

          egg = resolve_configured_egg(entry)
          next unless egg

          record = user.user_eggs.create!(
            egg: egg,
            hatched: false,
            hatch_started_at: nil
          )
          memo << {
            egg_id: egg.id,
            name: egg.name,
            user_egg_id: record.id
          }
        end
      end
    end

    def award_legacy_eggs(user, encounter_slug:)
      egg = pick_legacy_egg(encounter_slug)
      return [] unless egg

      record = user.user_eggs.create!(
        egg: egg,
        hatched: false,
        hatch_started_at: nil
      )

      [{
        egg_id: egg.id,
        name: egg.name,
        user_egg_id: record.id
      }]
    end

    def resolve_configured_egg(entry)
      scope = Egg.enabled
      if entry[:egg_id].present?
        scope.find_by(id: entry[:egg_id])
      elsif entry[:egg_name].present?
        scope.find_by(name: entry[:egg_name])
      else
        nil
      end
    end

    def item_pool_for(encounter_slug, outcome_key)
      case encounter_slug.to_s
      when "forest_lost_pup"
        DEFAULT_ITEM_POOL + %w[blanket treat]
      when "hidden_cache"
        DEFAULT_ITEM_POOL + %w[leveling_stone map normal_stone]
      else
        DEFAULT_ITEM_POOL
      end
    end

    def pick_legacy_egg(encounter_slug)
      scope = Egg.enabled
      case encounter_slug.to_s
      when "forest_lost_pup"
        scope.find_by(name: "Forest Egg") || scope.first
      else
        scope.order(Arel.sql("RANDOM()")).first || scope.first
      end
    end

    def reward_drop_keys_for(encounter_slug, outcome_key)
      entry = ExplorationEncounterStore.find(encounter_slug)&.data
      return [] unless entry

      rewards = (entry["rewards"] || {}).with_indifferent_access
      outcomes = rewards[:outcomes]
      outcome_hash = outcomes.is_a?(Hash) ? outcomes.with_indifferent_access : {}
      outcome_config = outcome_key.present? ? outcome_hash[outcome_key.to_s] : nil

      keys = extract_drop_keys(outcome_config)
      keys = extract_drop_keys(rewards) if keys.blank?
      keys
    end

    def extract_drop_keys(config)
      return [] unless config
      data = config["drop_keys"] || config["default_drop_keys"] || config["drop_key"]
      Array(data).map(&:to_s).reject(&:blank?)
    rescue NoMethodError
      []
    end
  end
end
