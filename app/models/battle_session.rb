class BattleSession < ApplicationRecord
  belongs_to :user
  belongs_to :world
  has_and_belongs_to_many :user_pets, -> { active }

  # Returns a Time when that ability can next be used, or nil if never used
  def next_available_at_for(ability)
    ts = ability_cooldowns[ability.id.to_s]
    ts.present? ? Time.iso8601(ts) : nil
  end

  # Server‐side application of an ability event:
  # - Enforces cooldown by comparing timestamp against next_available_at_for
  # - Applies ability.damage to enemy_hp
  # - Schedules the next_available_at_for = timestamp + ability.cooldown seconds
  def use_ability!(ability_id, timestamp)
    ability = Ability.find(ability_id)
    requested_time = timestamp.to_time

    # check cooldown
    if next_available_at = next_available_at_for(ability)
      raise StandardError, "Ability #{ability.name} on cooldown until #{next_available_at}" \
        if requested_time < next_available_at
    end

    # apply damage (or other effects)
    self.enemy_hp -= ability.damage

    # schedule next availability
    new_next = requested_time + ability.cooldown.seconds
    self.ability_cooldowns[ability.id.to_s] = new_next.iso8601
  end

  # … your other helpers (apply_auto_damage!, apply_manual_damage!, etc.) …
end
