class ItemAwarder
  class << self
    # Roll a database-driven loot table and award the resulting items to the user.
    # Returns an array of UserItem records that were updated/created.
    def open_loot_table(user, loot_table_key)
      loot_table = LootTable.includes(loot_entries: :item).find_by!(key: loot_table_key)
      entries = loot_table.loot_entries
      return [] if entries.empty?

      rng = Random.new
      awarded = []

      guaranteed_entries = entries.select { |entry| entry.constraints_json.present? && entry.constraints_json["guaranteed"] }
      guaranteed_entries.each do |entry|
        qty = entry.qty_min
        awarded << UserItem.add_to_inventory(user, entry.item, qty)
      end

      weighted_entries = entries.reject { |entry| entry.constraints_json.present? && entry.constraints_json["guaranteed"] }
      total_weight = weighted_entries.sum { |entry| entry.weight.to_i }

      if total_weight.positive?
        weighted_entries.each do |entry|
          weight = entry.weight.to_i
          next if weight <= 0

          chance = weight.to_f / total_weight.to_f
          next unless rng.rand < chance

          qty = if entry.qty_min == entry.qty_max
                  entry.qty_min
                else
                  rng.rand(entry.qty_min..entry.qty_max)
                end
          next if qty <= 0

          awarded << UserItem.add_to_inventory(user, entry.item, qty)
        end
      end

      awarded
    end

    def award_specific(user, item_type, qty = 1)
      item = find_item!(item_type)
      UserItem.add_to_inventory(user, item, qty)
    end

    private

    def find_item!(item_type)
      item = Item.find_by(item_type: item_type)
      raise ActiveRecord::RecordNotFound, "No Item with item_type=#{item_type}" unless item

      item
    end
  end
end
