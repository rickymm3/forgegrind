module ExplorationsHelper
  IMAGE_EXTENSIONS = %w[jpg jpeg png webp svg].freeze

  def world_zone_image_path(world)
    slug = world.name.to_s.parameterize
    IMAGE_EXTENSIONS.each do |ext|
      candidate = "zones/#{slug}.#{ext}"
      return asset_path(candidate) if asset_exists?(candidate)
    end

    asset_path("zones/placeholder-zone.svg")
  end

  def exploration_duration_label(seconds)
    total = seconds.to_i
    return "0:00" if total <= 0

    hours = total / 3600
    minutes = (total % 3600) / 60
    secs = total % 60

    if hours.positive?
      format("%d:%02d:%02d", hours, minutes, secs)
    else
      format("%d:%02d", minutes, secs)
    end
  end

  def expedition_segment_status(user_exploration, reference_time: Time.current)
    return nil unless user_exploration&.using_segments?

    total_segments = user_exploration.segment_progress_entries.size
    clock = user_exploration.active_segment_clock(reference_time: reference_time)

    if clock
      entry = clock[:entry] || {}
      index = entry[:index].to_i
      label = entry[:label].presence || "Checkpoint #{index + 1}"

      {
        state: :active,
        index: index,
        total: total_segments,
        label: label,
        remaining_seconds: clock[:remaining_seconds].to_i,
        duration_seconds: clock[:duration_seconds].to_i,
        end_time: clock[:end_time],
        allow_encounters: entry[:allow_encounters],
        encounters_enabled: entry[:encounters_enabled]
      }
    elsif (checkpoint_entry = user_exploration.checkpoint_segment_entry).present?
      index = checkpoint_entry[:index].to_i
      label = checkpoint_entry[:label].presence || "Checkpoint #{index + 1}"

      {
        state: :checkpoint,
        index: index,
        total: total_segments,
        label: label
      }
    else
      nil
    end
  end

  def checkpoint_encounter_result(user_exploration)
    return nil unless user_exploration

    entry = user_exploration.checkpoint_completed_encounter_entry
    return nil unless entry

    entry = entry.with_indifferent_access if entry.respond_to?(:with_indifferent_access)
    encounter = entry[:encounter]
    encounter = encounter.with_indifferent_access if encounter.respond_to?(:with_indifferent_access)
    options = Array(entry[:options]).map do |option|
      option.respond_to?(:with_indifferent_access) ? option.with_indifferent_access : option
    end
    history = Array(entry[:history]).map do |step|
      step.respond_to?(:with_indifferent_access) ? step.with_indifferent_access : step
    end

    last_step = history.last || {}
    choice_key = (last_step[:choice] || entry[:choice]).to_s.presence
    chosen_option = if choice_key.present?
                      options.find { |option| option[:key].to_s == choice_key }
                    end

    choice_label = if chosen_option&.[](:label).present?
                     encounter_text_for(user_exploration, chosen_option[:label], option: chosen_option)
                   elsif choice_key.present?
                     choice_key.humanize
                   end
    choice_description = if chosen_option&.[](:description).present?
                           encounter_text_for(user_exploration, chosen_option[:description], option: chosen_option)
                         end

    outcome_key = (last_step[:outcome] || entry[:outcome]).presence
    outcome_label = outcome_key.present? ? outcome_key.to_s.tr('_', ' ').humanize : nil

    rewards = entry[:rewards] || chosen_option&.[](:rewards)
    reward_summary = entry[:reward_summary].presence
    if reward_summary.blank?
      reward_summary = case rewards
                       when Hash
                         rewards.map { |k, v| "#{k.to_s.humanize}: #{v}" }.join(', ')
                       when Array
                         rewards.map(&:to_s).join(', ')
                       else
                         rewards.to_s if rewards.present?
                       end
    end

    {
      title: encounter&.[](:title).presence || "Encounter Resolved",
      summary: encounter&.[](:summary).present? ? encounter_text_for(user_exploration, encounter[:summary]) : nil,
      choice_label: choice_label,
      choice_description: choice_description,
      outcome_label: outcome_label,
      outcome_key: outcome_key,
      rewards: rewards,
      reward_summary: reward_summary,
      encounter: encounter,
      option: chosen_option,
      history: history
    }.compact
  end

  def encounter_text_for(user_exploration, text, option: nil)
    return text unless text.is_a?(String)

    context = encounter_context_for(user_exploration, option: option)
    return text if context.empty?

    text.gsub(/%\{([^\}]+)\}/) do
      key = Regexp.last_match(1)
      value = context[key.to_sym] || context[key.to_s]
      value.present? ? value : ""
    end
  end

  def encounter_requirement_labels(option)
    return [] unless option.respond_to?(:with_indifferent_access)

    option = option.with_indifferent_access
    requirements = option[:requires]
    return [] if requirements.blank?

    requirements = requirements.with_indifferent_access if requirements.respond_to?(:with_indifferent_access)
    labels = []

    ability_refs = Array(requirements[:special_abilities]).map(&:to_s).reject(&:blank?)
    if ability_refs.any?
      names = ability_refs.map { |ref| ability_name_for(ref) }.uniq
      labels << "Ability: #{names.join(', ')}"
    end

    tags = Array(requirements[:special_ability_tags]).map(&:to_s).reject(&:blank?)
    if tags.any?
      formatted = tags.map { |tag| tag.tr('_', ' ').titleize }
      labels << "Tag: #{formatted.join(', ')}"
    end

    labels
  end

  private

  def asset_exists?(logical_path)
    if Rails.application.config.assets.compile
      Rails.application.assets&.find_asset(logical_path).present?
    else
      Rails.application.assets_manifest&.assets&.key?(logical_path)
    end
  rescue StandardError
    false
  end

  def encounter_context_for(user_exploration, option: nil)
    return {} unless user_exploration

    members = Array(user_exploration.party_members).map do |entry|
      entry.respond_to?(:with_indifferent_access) ? entry.with_indifferent_access : entry
    end
    return {} if members.empty?

    primary_id = user_exploration.party_snapshot[:primary_user_pet_id]
    primary = members.find { |member| member[:user_pet_id].to_i == primary_id.to_i } || members.first
    focus_member = encounter_focus_member(members, option) || primary

    leader_name = primary[:display_name].presence || primary[:species] || "Leader"
    focus_name = focus_member[:display_name].presence || focus_member[:species] || leader_name
    focus_tags = Array(focus_member[:special_ability_tags]).map(&:to_s)

    party_names = members.map { |member| member[:display_name].presence || member[:species] }.compact

    context = {
      pet_name: focus_name,
      focus_pet_name: focus_name,
      leader_name: leader_name,
      leader_ability: primary[:special_ability_name],
      ability_name: focus_member[:special_ability_name],
      ability_tags: focus_tags.join(", "),
      party_names: party_names.to_sentence
    }
    context[:world_name] = user_exploration.world.name if user_exploration.world
    context
  end

  def encounter_focus_member(members, option)
    return members.first if option.blank?

    option = option.with_indifferent_access if option.respond_to?(:with_indifferent_access)
    requirements = option[:requires]
    return members.first if requirements.blank?

    requirements = requirements.with_indifferent_access if requirements.respond_to?(:with_indifferent_access)
    ability_refs = Array(requirements[:special_abilities]).map(&:to_s)
    if ability_refs.present?
      match = members.find do |member|
        ability_refs.include?(member[:special_ability_reference].to_s)
      end
      return match if match
    end

    tags = Array(requirements[:special_ability_tags]).map(&:to_s)
    if tags.present?
      match = members.find do |member|
        member_tags = Array(member[:special_ability_tags]).map(&:to_s)
        (member_tags & tags).any?
      end
      return match if match
    end

    members.first
  end

  def ability_name_for(reference)
    definitions = PetSpecialAbilityCatalog.ability_definitions
    entry = definitions[reference.to_s] || {}
    name = entry["name"] || entry[:name]
    return name if name.present?

    reference.to_s.tr('_', ' ').titleize
  rescue StandardError
    reference.to_s.tr('_', ' ').titleize
  end
end
