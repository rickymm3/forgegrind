module PetsHelper
  def pet_profile_image_path(user_pet)
    pet_sprite_path(user_pet.pet)
  end

  def pet_status_label(user_pet)
    if user_pet.exploring?
      "Exploring"
    elsif user_pet.asleep_until.present? && Time.current < user_pet.asleep_until
      "Sleeping"
    else
      "Ready"
    end
  end

  def pet_slot_dom_id(pet, index)
    base = pet.present? ? pet.id : "empty-#{index}"
    "pet-slot-#{base}"
  end

  def passive_coin_stats_for(pet)
    return {} unless pet&.active_slot.present?

    per_second = pet.coins_per_second
    cap = pet.rarity_coin_cap
    last_tick = pet.last_coin_tick_at || Time.current
    elapsed = [Time.current - last_tick, 0].max
    held = pet.coin_earned_today.to_i + (per_second * elapsed)
    held = [held, cap].min
    progress = cap.positive? ? (held / cap) : 0
    progress = progress.clamp(0.0, 1.0)

    {
      per_second: per_second.round(4),
      progress_percent: (progress * 100).round,
      pending_amount: held.floor,
      holding_cap: cap,
      multiplier: per_second.positive? ? (per_second / (5.0 / UserPet::ENERGY_INTERVAL)).round(2) : 0,
      ready: held >= 200
    }
  end
end
