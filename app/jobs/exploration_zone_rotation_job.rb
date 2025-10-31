class ExplorationZoneRotationJob < ApplicationJob
  queue_as :default

  DEFAULT_LIMIT = 6

  def perform(limit: DEFAULT_LIMIT)
    ActiveRecord::Base.transaction do
      World.update_all(rotation_active: false, rotation_starts_at: nil, rotation_ends_at: nil)

      candidates = World.active.order(Arel.sql("RANDOM()"))
      selected = candidates.limit(limit)
      rotation_window = rotation_window_range

      selected.each do |world|
        world.activate_rotation!(starts_at: rotation_window.begin, ends_at: rotation_window.end)
        assign_rotation_traits(world)
      end
    end
  end

  private

  def rotation_window_range
    now = Time.current
    start_time = now.beginning_of_day
    end_time = now.end_of_day
    start_time..end_time
  end

  def assign_rotation_traits(world)
    return if world.special_trait_keys.present? || world.upgrade_trait_keys_list.present?

    trait_choice = ZoneTraitLibrary.random_trait_keys.sample
    return unless trait_choice

    world.update!(
      special_traits: [trait_choice],
      required_pet_abilities: world.aggregate_required_abilities([trait_choice]),
      drop_table_override_key: world.aggregate_drop_override([trait_choice])
    )
  end
end
