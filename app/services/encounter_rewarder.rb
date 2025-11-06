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

      rewards = {}
      summary_parts = []

      awarded_items = award_items(user, encounter_slug: encounter_slug, outcome_key: outcome_key)
      if awarded_items.any?
        rewards[:items] = awarded_items
        summary_parts.concat(awarded_items.map do |entry|
          "#{entry[:name]} x#{entry[:quantity]}"
        end)
      end

      awarded_eggs = award_egg(user, encounter_slug: encounter_slug, outcome_key: outcome_key)
      if awarded_eggs.any?
        rewards[:eggs] = awarded_eggs
        summary_parts.concat(awarded_eggs.map { |entry| entry[:name] })
      end

      return nil if rewards.empty?

      {
        rewards: rewards,
        summary: summary_parts.join(", ")
      }
    rescue StandardError => e
      Rails.logger.debug do
        "[EncounterRewarder] Failed to award encounter rewards for exploration ##{user_exploration&.id}: #{e.message}"
      end
      nil
    end

    private

    def award_items(user, encounter_slug:, outcome_key:)
      pool = item_pool_for(encounter_slug, outcome_key)
      return [] if pool.blank?

      rng = Random.new
      count = 1 + rng.rand(0..1) # one or two items

      Array.new(count).filter_map do
        item_type = pool.sample(random: rng)
        next unless item_type

        user_item = ItemAwarder.award_specific(user, item_type, 1)
        {
          item_type: item_type,
          quantity: 1,
          name: user_item.item.name
        }
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

    def award_egg(user, encounter_slug:, outcome_key:)
      egg = pick_egg(encounter_slug, outcome_key)
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

    def pick_egg(encounter_slug, outcome_key)
      scope = Egg.enabled

      case encounter_slug.to_s
      when "forest_lost_pup"
        scope.find_by(name: "Forest Egg") || scope.first
      else
        scope.order(Arel.sql("RANDOM()")).first || scope.first
      end
    end
  end
end
