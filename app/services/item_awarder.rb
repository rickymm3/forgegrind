# app/services/item_awarder.rb

class ItemAwarder
  CONFIG_PATH = Rails.root.join("config", "item_rewards.yml")

  class << self
    # Opens a named bucket (e.g. "world_1_chest_common"),
    # awards all guaranteed items plus any weighted items that roll successfully.
    # Returns an array of UserItem records (one per awarded item).
    #
    # Example:
    #   awarded = ItemAwarder.open_bucket(current_user, "world_1_chest_common")
    #   # => [<UserItem frisbee x1>, <UserItem starter_item x1>, <UserItem blanket x1>]
    def open_bucket(user, bucket_name)
      bucket = rewards[bucket_name]
      return [] unless bucket.present?

      awarded = []

      # 1. Award guaranteed items first (weight is ignored)
      bucket.each do |item_type, settings|
        next unless settings["guaranteed"] == true

        awarded << award_specific(user, item_type, 1)
      end

      # 2. Collect all items that have weight > 0 (i.e., “weighted items”)
      weighted_entries = bucket.select { |item_type, settings| settings["weight"].to_i > 0 }

      # If there are any weighted items, sum their weights to normalize probabilities
      if weighted_entries.any?
        total_weight = weighted_entries.values.sum { |settings| settings["weight"].to_i }

        weighted_entries.each do |item_type, settings|
          weight = settings["weight"].to_i
          # Roll a random number between 0...1; if it’s < (weight/total_weight),
          # award that item. Because each is independent, you can end up with multiple.
          if rand < (weight.to_f / total_weight)
            awarded << award_specific(user, item_type, 1)
          end
        end
      end

      awarded.compact
    end

    # Deterministically award `qty` of the given item_type to `user`.
    # Returns the UserItem record.
    def award_specific(user, item_type, qty = 1)
      item = find_item!(item_type)
      UserItem.add_to_inventory(user, item, qty)
    end

    private

    # Helper to find an Item by item_type or raise if missing.
    def find_item!(item_type)
      item = Item.find_by(item_type: item_type)
      raise ActiveRecord::RecordNotFound, "No Item with item_type=#{item_type}" unless item

      item
    end

    def rewards
      @rewards ||= load_rewards
    end

    def load_rewards
      return {}.with_indifferent_access unless CONFIG_PATH.exist?

      YAML.load_file(CONFIG_PATH).with_indifferent_access
    rescue StandardError => e
      Rails.logger.warn("[ItemAwarder] Failed to load rewards: #{e.message}")
      {}.with_indifferent_access
    end
  end
end
