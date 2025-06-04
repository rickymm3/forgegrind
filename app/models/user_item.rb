class UserItem < ApplicationRecord
  belongs_to :user
  belongs_to :item

  validates :quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # increment or create
  def self.add_to_inventory(user, item, amount = 1)
    record = find_or_initialize_by(user: user, item: item)
    record.quantity += amount
    record.save!
    record
  end

  def self.open_bucket(user:, bucket_name:)
    # 1. Load the YAML and fetch the bucket
    raw = YAML.load_file(Rails.root.join("config/item_buckets.yml"))
                .with_indifferent_access
    bucket = raw[bucket_name]
    raise ArgumentError, "Bucket #{bucket_name.inspect} not found in config/item_buckets.yml" unless bucket

    awarded = []

    # 2. Award guaranteed items (by name)
    bucket.each do |item_name, config|
      if config["guaranteed"]
        item = Item.find_by!(name: item_name)
        awarded << add_to_inventory(user, item, 1)
      end
    end

    # 3. Collect weighted entries
    weighted_entries = bucket.select { |_, config| config["weight"].to_i > 0 }

    if weighted_entries.any?
      total_weight = weighted_entries.values.sum { |cfg| cfg["weight"].to_i }

      # 4. For each weighted entry, roll independently
      weighted_entries.each do |item_name, config|
        weight = config["weight"].to_i
        chance = weight.to_f / total_weight
        if rand < chance
          item = Item.find_by!(name: item_name)
          awarded << add_to_inventory(user, item, 1)
        end
      end
    end

    awarded
  end
end
