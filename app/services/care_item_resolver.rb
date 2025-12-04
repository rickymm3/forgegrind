require "ostruct"

class CareItemResolver
  def initialize(user)
    @user = user
  end

  def available_for(interaction)
    entries = CareItemCatalog.for_interaction(interaction)
    return [] if entries.empty?

    entries.filter_map do |entry|
      user_item = inventory[entry.item_type]
      next unless user_item&.quantity.to_i.positive?

      entry_data = entry.to_h.merge(
        quantity: user_item.quantity.to_i,
        user_item_id: user_item.id
      )
      OpenStruct.new(entry_data)
    end
  end

  private

  attr_reader :user

  def inventory
    @inventory ||= user.user_items.includes(:item).index_by { |ui| ui.item&.item_type }
  end
end
