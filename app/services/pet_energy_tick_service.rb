# frozen_string_literal: true

class PetEnergyTickService
  NEED_KEYS = %i[hunger hygiene boredom injury_level mood].freeze
  TRACKER_KEYS = {
    hunger: :hunger_score,
    hygiene: :hygiene_score,
    boredom: :boredom_score,
    injury_level: :injury_score,
    mood: :mood_score
  }.freeze

  GOOD_THRESHOLD = 60
  BAD_THRESHOLD  = 40
  TRACKER_MIN    = 0
  TRACKER_MAX    = 100

  def initialize(user_pet)
    @user_pet = user_pet
  end

  def apply_ticks!(tick_count)
    ticks = tick_count.to_i
    return if ticks <= 0

    apply_single_tick(ticks)
  end

  private

  attr_reader :user_pet

  def apply_single_tick(ticks)
    # Needs decay is handled by catch_up_needs! before invoking this service.
    update_trackers(ticks)
    update_badges
  end

  def update_trackers(ticks)
    trackers = user_pet.care_trackers.deep_dup

    NEED_KEYS.each do |need|
      tracker_key = TRACKER_KEYS[need]
      next unless tracker_key

      base_value = trackers.fetch(tracker_key.to_s, 50).to_i
      delta = tracker_delta_for(need) * ticks
      trackers[tracker_key.to_s] = clamp_tracker(base_value + delta)
    end

    user_pet.update_column(:care_trackers, trackers)
  end

  def update_badges
    engine = BadgeEngine.new(user_pet)
    result = engine.evaluate!
    return if result[:gained].empty? && result[:removed].empty?

    new_badges = user_pet.badges.map(&:to_s)
    new_badges -= result[:removed]
    new_badges |= result[:gained]

    user_pet.update_column(:badges, new_badges)
  end

  def tracker_delta_for(need)
    value = user_pet.send(need).to_i

    if value >= GOOD_THRESHOLD
      1
    elsif value <= BAD_THRESHOLD
      -1
    else
      0
    end
  end

  def clamp_tracker(value)
    [[value, TRACKER_MIN].max, TRACKER_MAX].min
  end
end
