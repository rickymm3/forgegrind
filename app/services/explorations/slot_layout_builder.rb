module Explorations
  class SlotLayoutBuilder
    Entry = Struct.new(
      :slot_index,
      :generated_exploration,
      :user_exploration,
      :requirement_progress,
      :requirement_groups,
      :selected,
      :state,
      :cooldown_seconds,
      :cooldown_ends_at,
      :reroll_cooldown_seconds,
      :reroll_available_at,
      keyword_init: true
    )

    def self.build(max_slots:, generated_explorations:, active_explorations:, requirement_map:, selected_generated: nil)
      generated_by_slot = generated_explorations.index_by(&:slot_index)
      active_by_slot = {}
      active_explorations.each do |user_exploration|
        slot_index = user_exploration.generated_exploration&.slot_index
        next unless slot_index

        active_by_slot[slot_index] = user_exploration
      end

      (1..max_slots).map do |slot|
        generated = generated_by_slot[slot]
        user_exploration = active_by_slot[slot]
        generated ||= user_exploration&.generated_exploration

        progress = []
        grouped = {}

        if generated && user_exploration
          progress = generated.requirements_progress_for(user_exploration.user_pets)
          grouped = progress.group_by { |entry| entry[:source] || "base" }
        elsif generated
          entry = requirement_map[generated.id] || { progress: [], grouped: {} }
          progress = entry[:progress]
          grouped = entry[:grouped]
        end

        state = if user_exploration.present?
                  user_exploration.complete? ? :ready : :active
                elsif generated.nil?
                  :empty
                elsif generated.slot_state_sym == :cooldown
                  :cooldown
                else
                  :available
                end

        cooldown_seconds = generated&.cooldown_remaining_seconds || 0
        reroll_seconds = generated&.reroll_cooldown_remaining_seconds || 0

        Entry.new(
          slot_index: slot,
          generated_exploration: generated,
          user_exploration: user_exploration,
          requirement_progress: progress,
          requirement_groups: grouped,
          selected: selected_generated.present? && generated.present? && selected_generated.id == generated.id,
          state: state,
          cooldown_seconds: cooldown_seconds,
          cooldown_ends_at: generated&.cooldown_ends_at,
          reroll_cooldown_seconds: reroll_seconds,
          reroll_available_at: generated&.reroll_available_at
        )
      end
    end
  end
end
