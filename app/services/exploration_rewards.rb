class ExplorationRewards
  CONFIG_PATH = Rails.root.join("config", "exploration_rewards.yml")
  DEFAULTS = {
    "starter_zone" => {
      "exp" => 10,
      "diamonds" => 50,
      "items" => {
        "starter_item" => 1
      }
    },
    "forest" => {
      "exp" => 20,
      "diamonds" => 75,
      "items" => {
        "wooden_stick" => 1
      }
    }
  }.freeze
  Reward = Struct.new(:exp, :diamonds, :items, :flags, :eggs, keyword_init: true)

  class << self
    def for(world)
      reward_from_config(merged_config_for(world_key(world)))
    end

    def for_drop_key(key)
      return nil if key.blank?

      reward_from_config(merged_config_for(key))
    end

    def for_drop_keys(keys, fallback_world: nil)
      rewards = Array(keys).compact.map { |key| for_drop_key(key) }.compact
      if rewards.empty? && fallback_world.present?
        rewards << self.for(fallback_world)
      end
      rewards = [Reward.new(exp: 0, diamonds: 0, items: {}, flags: {})] if rewards.empty?
      combine_rewards(rewards)
    end

    def reload!
      @config = load_config
    end

    def resolve_item_drops(items_config)
      return {} unless items_config.present?

      items_config.each_with_object({}) do |(item_type, data), memo|
        config = data.respond_to?(:symbolize_keys) ? data.symbolize_keys : data
        quantity = config[:quantity].to_i
        chance   = config[:chance].nil? ? 1.0 : config[:chance].to_f
        awarded  = roll_item_drop(quantity, chance)
        memo[item_type] = awarded if awarded.positive?
      end
    end

    private

    def config
      @config ||= load_config
    end

    def merged_config_for(key)
      return {} if key.blank?

      base = DEFAULTS[key.to_s]&.deep_dup || {}
      overrides = config[key.to_s] || {}
      base.deep_merge(overrides)
    end

    def load_config
      if CONFIG_PATH.exist?
        YAML.load_file(CONFIG_PATH).with_indifferent_access
      else
        {}.with_indifferent_access
      end
    end

    def reward_from_config(data)
      data ||= {}
      Reward.new(
        exp: data.fetch("exp", 0).to_i,
        diamonds: data.fetch("diamonds", 0).to_i,
        items: normalize_items(data["items"]),
        flags: normalize_flags(data["flags"]),
        eggs: normalize_eggs(data["eggs"])
      )
    end

    def combine_rewards(rewards)
      exp = 0
      diamonds = 0
      items = {}
      flags = {}
      eggs = {}

      rewards.each do |reward|
        exp += reward.exp.to_i
        diamonds += reward.diamonds.to_i
        reward.items.each do |item_type, definition|
          current = items[item_type] ||= { quantity: 0, chance: 0.0 }
          current[:quantity] += definition[:quantity].to_i
          current[:chance] = [current[:chance], definition[:chance].to_f].max
        end
        flags.deep_merge!(reward.flags) if reward.flags.present?
        reward.eggs.each do |egg_key, definition|
          current = eggs[egg_key] ||= { quantity: 0, chance: 0.0, egg_id: nil, egg_name: nil }
          current[:quantity] += definition[:quantity].to_i
          current[:chance] = [current[:chance], definition[:chance].to_f].max
          current[:egg_id] ||= definition[:egg_id]
          current[:egg_name] ||= definition[:egg_name]
        end
      end

      Reward.new(exp: exp, diamonds: diamonds, items: items, flags: flags, eggs: eggs)
    end

    def normalize_items(items)
      return {} unless items

      items.each_with_object({}) do |(item_type, data), memo|
        normalized = normalize_single_item(data)
        memo[item_type.to_s] = normalized if normalized
      end
    end

    def normalize_flags(flags)
      return {} unless flags

      flags.each_with_object({}) do |(flag_name, rule), memo|
        memo[flag_name.to_s] = (rule || {}).stringify_keys
      end
    end

    def normalize_eggs(eggs)
      return {} unless eggs

      eggs.each_with_object({}) do |(key, data), memo|
        normalized = normalize_single_egg(key, data)
        memo[key.to_s] = normalized if normalized
      end
    end

    def world_key(world)
      if world.respond_to?(:name)
        world.name.to_s.parameterize(separator: '_')
      else
        world.to_s
      end
    end

    def normalize_single_item(data)
      case data
      when Hash
        hash = data.with_indifferent_access
        quantity = (hash[:quantity] || hash[:qty] || hash[:amount] || 0).to_i
        chance   = hash.key?(:chance) ? hash[:chance].to_f : 1.0
      else
        quantity = data.to_i
        chance   = 1.0
      end

      return nil if quantity <= 0

      {
        quantity: quantity,
        chance: chance.clamp(0.0, 1.0)
      }
    end

    def normalize_single_egg(key, data)
      hash =
        case data
        when Hash
          data.with_indifferent_access
        else
          { quantity: data.to_i }
        end

      quantity = hash[:quantity].to_i
      return nil if quantity <= 0

      chance = hash.key?(:chance) ? hash[:chance].to_f : 1.0
      egg_id = hash[:egg_id].presence
      egg_name = hash[:egg_name].presence || hash[:name].presence || key.to_s.humanize

      {
        quantity: quantity,
        chance: chance.clamp(0.0, 1.0),
        egg_id: egg_id,
        egg_name: egg_name
      }
    end

    def roll_item_drop(quantity, chance)
      quantity = quantity.to_i
      chance   = chance.to_f
      return 0 if quantity <= 0 || chance <= 0.0
      return quantity if chance >= 1.0

      awarded = 0
      quantity.times do
        awarded += 1 if rand < chance
      end
      awarded
    end
  end
end
