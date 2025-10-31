module Containers
  class ContainerOpener
    Result = Struct.new(:opened, :chest_type, :rewards, :request_uuid, :remaining_count, keyword_init: true)

    class Error < StandardError; end
    class InsufficientContainers < Error; end
    class BatchNotAllowed < Error; end

    def self.call(user:, chest_type_key:, quantity: 1, request_uuid: nil, latency_ms: nil, client_version: nil)
      new(
        user: user,
        chest_type_key: chest_type_key,
        quantity: quantity,
        request_uuid: request_uuid,
        latency_ms: latency_ms,
        client_version: client_version
      ).call
    end

    def initialize(user:, chest_type_key:, quantity:, request_uuid:, latency_ms:, client_version:)
      @user = user
      @quantity = quantity.to_i
      @request_uuid = request_uuid.presence || SecureRandom.uuid
      @latency_ms = latency_ms
      @client_version = client_version
      @chest_type = ChestType.find_by!(key: chest_type_key)
    end

    def call
      existing_event = ContainerOpenEvent.includes(:chest_type).find_by(request_uuid: request_uuid)
      if existing_event
        raise Error, "request_uuid is owned by another user" if existing_event.user_id != user.id
        return build_result(existing_event.chest_type, existing_event.opened_qty, existing_event.rewards_json, remaining_count: current_count(existing_event.chest_type), request_uuid: existing_event.request_uuid)
      end

      raise InsufficientContainers, "Quantity must be positive" if quantity <= 0
      if quantity > 1 && !chest_type.open_batch_allowed?
        raise BatchNotAllowed, "#{chest_type.name} cannot be opened in batches"
      end

      rewards_array = []
      remaining = nil

      ActiveRecord::Base.transaction do
        container = user.user_containers.lock.find_by(chest_type: chest_type)
        raise InsufficientContainers, "No containers available" unless container
        raise InsufficientContainers, "Not enough containers" if container.count < quantity

        rewards_map = roll_rewards(quantity)
        rewards_array = apply_rewards(rewards_map)

        container.count -= quantity
        if container.count.positive?
          container.save!
          remaining = container.count
        else
          container.destroy!
          remaining = 0
        end

        ContainerOpenEvent.create!(
          user: user,
          chest_type: chest_type,
          opened_qty: quantity,
          rewards_json: rewards_array,
          latency_ms: latency_ms,
          client_version: client_version,
          request_uuid: request_uuid
        )
      end

      build_result(chest_type, quantity, rewards_array, remaining_count: remaining, request_uuid: request_uuid)
    end

    private

    attr_reader :user, :chest_type, :quantity, :request_uuid, :latency_ms, :client_version

    def roll_rewards(open_count)
      loot_table = chest_type.default_loot_table
      entries = loot_table.loot_entries.includes(:item).to_a
      raise Error, "Loot table #{loot_table.key} has no entries" if entries.empty?

      rng = Random.new
      rewards = {}

      open_count.times do
        rolls = rng.rand(loot_table.rolls_min..loot_table.rolls_max)
        rolls.times do
          entry = WeightedPicker.pick(entries.map { |loot_entry| { value: loot_entry, weight: loot_entry.weight } }, rng: rng)
          next unless entry

          quantity = rng.rand(entry.qty_min..entry.qty_max)
          next if quantity <= 0

          data = (rewards[entry.item_id] ||= {
            item: entry.item,
            qty: 0,
            rarity: entry.rarity,
            icon: item_icon_for(entry.item)
          })
          data[:qty] += quantity
          data[:rarity] = entry.rarity if rarity_rank(entry.rarity) > rarity_rank(data[:rarity])
        end
      end

      rewards
    end

    def apply_rewards(rewards_map)
      rewards_map.values.map do |reward|
        UserItem.add_to_inventory(user, reward[:item], reward[:qty])
        {
          "item_id" => reward[:item].id,
          "name" => reward[:item].name,
          "item_type" => reward[:item].item_type,
          "qty" => reward[:qty],
          "rarity" => reward[:rarity],
          "icon" => reward[:icon]
        }
      end
    end

    def current_count(type)
      user.user_containers.where(chest_type: type).pick(:count).to_i
    end

    def build_result(type, opened_qty, rewards_array, remaining_count:, request_uuid:)
      Result.new(
        opened: opened_qty,
        chest_type: {
          key: type.key,
          name: type.name,
          icon: type.icon
        },
        rewards: rewards_array,
        remaining_count: remaining_count,
        request_uuid: request_uuid
      )
    end

    def item_icon_for(item)
      ApplicationController.helpers.care_item_image_path(item.item_type)
    rescue StandardError => e
      Rails.logger.debug { "[ContainerOpener] icon lookup failed for #{item.item_type}: #{e.message}" }
      nil
    end

    RARITY_ORDER = {
      "common" => 0,
      "uncommon" => 1,
      "rare" => 2,
      "epic" => 3,
      "legendary" => 4
    }.freeze

    def rarity_rank(rarity)
      RARITY_ORDER[rarity.to_s] || 0
    end
  end
end
