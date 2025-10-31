module Explorations
  class ExplorationCompletionRewarder
    DEFAULT_CHEST_KEY = "pet_care_box_lvl1".freeze

    def self.call(user:, world:)
      new(user: user, world: world).call
    end

    def initialize(user:, world:)
      @user = user
      @world = world
    end

    def call
      chest_type = pick_chest_type
      user_container = UserContainer.find_or_initialize_by(user: user, chest_type: chest_type)
      user_container.count = user_container.count.to_i + 1
      user_container.acquired_source = "exploration_completion"
      user_container.save!

      { chest_type: chest_type, user_container: user_container }
    end

    private

    attr_reader :user, :world

    def pick_chest_type
      entries = ZoneChestDrop.weighted_pairs_for(world)
      if entries.blank?
        default = default_chest_type
        entries = [{ chest_type: default, weight: 100 }]
      end

      WeightedPicker.pick(entries) || default_chest_type
    end

    def default_chest_type
      ChestType.find_by!(key: DEFAULT_CHEST_KEY)
    end
  end
end
