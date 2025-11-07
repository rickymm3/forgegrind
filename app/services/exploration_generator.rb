class ExplorationGenerator
  DEFAULT_COUNT = 3
  RESCOUT_COOLDOWN = 10.minutes
  RARITY_ORDER = {
    "common" => 1,
    "uncommon" => 2,
    "rare" => 3,
    "epic" => 4,
    "legendary" => 5,
    "mythic" => 6
  }.freeze

  class CooldownNotElapsedError < StandardError
    attr_reader :remaining_seconds

    def initialize(remaining_seconds)
      @remaining_seconds = remaining_seconds
      super("Rescout available in #{remaining_seconds} seconds")
    end
  end

  def initialize(user)
    @user = user
  end

  def generate!(count: DEFAULT_COUNT, force: false, slot_index: nil)
    ActiveRecord::Base.transaction do
      user.lock!
      ensure_cooldown!(force) unless slot_index

      slot_indices = slot_index ? [slot_index] : (1..count.to_i).to_a
      active_slots = active_slot_indices
      existing_by_slot = user.generated_explorations.where(slot_index: slot_indices).index_by(&:slot_index)

      user.update!(last_scouted_at: Time.current) unless slot_index

      slot_indices.each do |index|
        next if active_slots.include?(index)

        existing = existing_by_slot[index]
        next if existing&.cooldown_active? && !force

        user.generated_explorations.where(slot_index: index).delete_all
        create_generated_exploration(slot_index: index)
      end
    end
  end

  def self.cooldown_remaining_for(user)
    return 0 unless user&.last_scouted_at.present?

    elapsed = Time.current - user.last_scouted_at
    remaining = RESCOUT_COOLDOWN.to_i - elapsed
    remaining.positive? ? remaining.ceil : 0
  end

  private

  attr_reader :user

  def active_slot_indices
    user.user_explorations
        .where(completed_at: nil)
        .includes(:generated_exploration)
        .map { |exploration| exploration.generated_exploration&.slot_index }
        .compact
  end

  def create_generated_exploration(slot_index:)
    base_key, base_config = ExplorationModLibrary.sample_base
    raw_prefix_key, prefix_config = ExplorationModLibrary.sample_prefix
    raw_suffix_key, suffix_config = ExplorationModLibrary.sample_suffix

    prefix_key = normalize_component_key(raw_prefix_key)
    suffix_key = normalize_component_key(raw_suffix_key)

    combination_key, combination_config = ExplorationModLibrary.combination(prefix_key || raw_prefix_key, base_key, suffix_key || raw_suffix_key)
    combination_config = combination_config.with_indifferent_access if combination_config.present?

    world = resolve_world(base_config)
    duration = compute_duration(base_config, prefix_config, suffix_config, combination_config)
    name = build_name(base_config, prefix_config, suffix_config, combination_config)
    requirements = merge_requirements(
      [base_config, 'base'],
      [prefix_config, 'prefix'],
      [suffix_config, 'suffix'],
      [combination_config, 'combination']
    )
    reward_config = merge_rewards(
      [base_config, 'base'],
      [prefix_config, 'prefix'],
      [suffix_config, 'suffix'],
      [combination_config, 'combination']
    )
    segment_definitions = build_segment_definitions(duration, base_config, prefix_config, suffix_config, combination_config)
    duration = segment_definitions.sum { |segment| segment[:duration_seconds].to_i } if segment_definitions.present?

    rarity_info = determine_rarity(base_config, prefix_config, suffix_config, combination_config, combination_key)
    metadata = build_metadata(
      base_key,
      normalize_storage_key(raw_prefix_key),
      normalize_storage_key(raw_suffix_key),
      base_config,
      prefix_config,
      suffix_config,
      combination_config,
      rarity_info,
      combination_key
    ).merge(
      slot_state: GeneratedExploration::SLOT_STATE_ACTIVE,
      reroll_available_at: nil
    )

    user.generated_explorations.create!(
      world: world,
      base_key: base_key,
      prefix_key: normalize_storage_key(raw_prefix_key),
      suffix_key: normalize_storage_key(raw_suffix_key),
      name: name,
      duration_seconds: duration,
      requirements: requirements,
      reward_config: reward_config,
      metadata: metadata,
      segment_definitions: stringify_segments(segment_definitions),
      scouted_at: Time.current,
      expires_at: Time.current.end_of_day,
      slot_index: slot_index,
      cooldown_ends_at: nil
    )
  end

  def resolve_world(base_config)
    world_name = base_config[:world_name] || base_config['world_name']
    World.find_by(name: world_name) || World.active.first || raise(ActiveRecord::RecordNotFound, "World not found for base #{world_name}")
  end

  def compute_duration(*configs)
    base_config = configs[0]
    duration = minutes_to_seconds(fetch_float(base_config, :default_duration))
    multiplier = 1.0
    additive = 0

    configs.each do |config|
      next unless config

      multiplier *= config[:duration_multiplier].to_f if config[:duration_multiplier]
      if config[:duration_bonus]
        additive += minutes_to_seconds(config[:duration_bonus])
      elsif config[:duration_bonus_minutes]
        additive += minutes_to_seconds(config[:duration_bonus_minutes])
      end
    end

    [(duration * multiplier).to_i + additive, 300].max
  end

  def build_name(base_config, prefix_config, suffix_config, combination_config)
    if combination_config && combination_config[:label_override].present?
      return combination_config[:label_override]
    end

    parts = []
    parts << prefix_config&.[](:label) if prefix_config && prefix_config[:label].present?
    parts << base_config[:label]
    parts << suffix_config&.[](:label) if suffix_config && suffix_config[:label].present?
    parts.compact.join(' ')
  end

  def merge_requirements(*config_tuples)
    config_tuples.compact.flat_map do |config, origin|
      next [] unless config

      source_label = config[:label]&.parameterize || origin
      Array(config[:requirements]).map.with_index do |req, idx|
        req.with_indifferent_access.merge(
          id: "#{source_label}_#{idx}",
          source: origin,
          required: req[:required].to_i
        )
      end
    end
  end

  def merge_rewards(*config_tuples)
    reward_entries = {}

    config_tuples.compact.each do |config, origin|
      next unless config

      key = config[:label]&.parameterize || origin
      rewards = (config[:rewards] || {}).with_indifferent_access
      rewards[:category] ||= origin
      reward_entries[key] = rewards
    end

    reward_entries
  end

  def build_metadata(base_key, prefix_key, suffix_key, base_config, prefix_config, suffix_config, combination_config, rarity_info, combination_key)
    flavor_fragments = [
      base_config&.dig(:flavor),
      prefix_config&.dig(:flavor),
      suffix_config&.dig(:flavor)
    ].compact
    flavor_fragments << combination_config[:flavor_append] if combination_config&.dig(:flavor_append).present?

    encounter_tags = []
    encounter_tags.concat(Array(base_config[:encounter_tags])) if base_config
    encounter_tags.concat(Array(prefix_config[:encounter_tags])) if prefix_config
    encounter_tags.concat(Array(suffix_config[:encounter_tags])) if suffix_config
    encounter_tags.concat(Array(combination_config[:encounter_tags])) if combination_config
    encounter_tags = encounter_tags.flatten.compact.uniq

    {
      flavor: flavor_fragments,
      rarity: rarity_info[:key],
      rarity_label: rarity_info[:label],
      rarity_color: rarity_info[:color],
      rarity_score: rarity_info[:score],
      components: {
        base: base_key,
        prefix: prefix_key,
        suffix: suffix_key
      },
      combination_key: combination_key,
      encounter_tags: encounter_tags
    }.compact
  end

  def build_segment_definitions(total_duration_seconds, base_config, prefix_config, suffix_config, combination_config = nil)
    total_duration_seconds = total_duration_seconds.to_i
    total_duration_seconds = 1 if total_duration_seconds <= 0

    templates = gather_segment_templates(
      [base_config, 'base'],
      [prefix_config, 'prefix'],
      [suffix_config, 'suffix'],
      [combination_config, 'combination']
    )

    if templates.blank?
      count = compute_default_segment_count(base_config, prefix_config, suffix_config)
      durations = split_duration(total_duration_seconds, count)
      templates = durations.each_with_index.map do |duration, index|
        {
          key: "segment_#{index + 1}",
          label: default_segment_label(index),
          duration_seconds: duration,
          source: 'generated'
        }
      end
    else
      templates = normalize_segment_templates(templates, total_duration_seconds)
    end

    cumulative = 0
    templates.each_with_index.map do |template, index|
      segment = template.deep_dup.with_indifferent_access
      segment = segment.except(
        :duration_minutes,
        :duration_weight,
        :ratio,
        :proportion,
        :weight,
        :_template_index
      )

      segment_key = segment[:key].presence || "segment_#{index + 1}"
      segment_label = segment[:label].presence || default_segment_label(index)
      duration = segment[:duration_seconds].to_i
      duration = 1 if duration <= 0

      cumulative += duration

      segment.merge(
        key: segment_key.to_s,
        label: segment_label,
        index: index,
        duration_seconds: duration,
        checkpoint_offset_seconds: cumulative
      ).with_indifferent_access
    end
  end

  def gather_segment_templates(*config_pairs)
    config_pairs.compact.flat_map do |config, source|
      next [] unless config

      Array(config[:segments]).each_with_index.map do |entry, index|
        entry_hash = entry.respond_to?(:with_indifferent_access) ? entry.with_indifferent_access : entry
        entry_hash.merge(
          source: entry_hash[:source].presence || source,
          _template_index: index
        )
      end
    end
  end

  def normalize_segment_templates(templates, total_duration_seconds)
    segments = templates.map do |template|
      entry = template.respond_to?(:with_indifferent_access) ? template.with_indifferent_access : template
      dup = entry.deep_dup
      dup[:_base_seconds] = extract_base_seconds(dup)
      dup[:_weight] = extract_weight(dup)
      dup
    end

    base_total = segments.sum { |segment| segment[:_base_seconds].to_i }

    if base_total.positive?
      scale = total_duration_seconds.to_f / base_total
      segments.each do |segment|
        duration = (segment[:_base_seconds].to_i * scale).round
        segment[:duration_seconds] = [duration, 1].max
      end
    else
      weight_total = segments.sum { |segment| segment[:_weight].to_f }
      weight_total = segments.size.to_f if weight_total <= 0

      segments.each do |segment|
        weight = segment[:_weight].to_f
        weight = 1.0 if weight <= 0
        duration = (total_duration_seconds * (weight / weight_total)).round
        segment[:duration_seconds] = [duration, 1].max
      end
    end

    adjust_duration_totals!(segments, total_duration_seconds)

    segments.each do |segment|
      segment.delete(:_base_seconds)
      segment.delete(:_weight)
    end
  end

  def extract_base_seconds(segment)
    seconds = segment[:duration_seconds].to_i
    minutes = segment[:duration_minutes].to_i

    if seconds.positive?
      seconds
    elsif minutes.positive?
      minutes * 60
    else
      0
    end
  end

  def extract_weight(segment)
    return segment[:weight] if segment.key?(:weight)
    return segment[:duration_weight] if segment.key?(:duration_weight)
    return segment[:ratio] if segment.key?(:ratio)
    return segment[:proportion] if segment.key?(:proportion)

    1.0
  end

  def adjust_duration_totals!(segments, total_duration_seconds)
    total_assigned = segments.sum { |segment| segment[:duration_seconds].to_i }
    difference = total_duration_seconds - total_assigned
    return if difference.zero?

    if difference.positive?
      segments.last[:duration_seconds] += difference
    else
      remaining = -difference
      segments.reverse_each do |segment|
        break if remaining <= 0

        available = segment[:duration_seconds] - 1
        next if available <= 0

        reduction = [available, remaining].min
        segment[:duration_seconds] -= reduction
        remaining -= reduction
      end

      segments.first[:duration_seconds] += remaining if remaining.positive?
    end
  end

  def compute_default_segment_count(base_config, prefix_config, suffix_config)
    count = fetch_integer(base_config, :segment_count)
    count = 2 if count <= 0

    modifiers = [
      fetch_integer(prefix_config, :segment_count_bonus, :additional_segments),
      fetch_integer(suffix_config, :segment_count_bonus, :additional_segments)
    ].sum

    multipliers = [
      fetch_float(prefix_config, :segment_count_multiplier),
      fetch_float(suffix_config, :segment_count_multiplier)
    ].reject(&:zero?)

    count += modifiers
    multipliers.each do |multiplier|
      count = (count * multiplier).round
    end

    count = 2 if count <= 0
    count = count.clamp(2, 6)
    count
  end

  def split_duration(total_duration_seconds, segment_count)
    count = segment_count.to_i
    count = 1 if count <= 0

    base = total_duration_seconds / count
    remainder = total_duration_seconds % count

    Array.new(count) do |index|
      duration = base
      duration += 1 if index < remainder
      [duration, 1].max
    end
  end

  def default_segment_label(index)
    "Checkpoint #{index + 1}"
  end

  def stringify_segments(segments)
    Array(segments).map do |segment|
      segment.respond_to?(:stringify_keys) ? segment.stringify_keys : segment
    end
  end

  def fetch_integer(config, *keys)
    return 0 unless config

    keys.each do |key|
      value = config[key]
      return value.to_i if value.present?
    end
    0
  end

  def fetch_float(config, *keys)
    return 0.0 unless config

    keys.each do |key|
      value = config[key]
      return value.to_f if value.present?
    end
    0.0
  end

  def minutes_to_seconds(value)
    (value.to_f * 60).round
  end

  def ensure_cooldown!(force)
    return if force

    remaining = self.class.cooldown_remaining_for(user)
    raise CooldownNotElapsedError.new(remaining) if remaining.positive?
  end

  def normalize_component_key(key)
    return nil if key.blank? || key == "none"
    key
  end

  def normalize_storage_key(key)
    normalize_component_key(key)
  end

  def determine_rarity(base_config, prefix_config, suffix_config, combination_config, combination_key)
    palette = ExplorationModLibrary.rarity_palette
    combination_key = nil

    component_rarities = [
      base_config&.dig(:rarity),
      prefix_config&.dig(:rarity),
      suffix_config&.dig(:rarity)
    ].compact

    rarity_key = component_rarities.max_by { |key| RARITY_ORDER.fetch(key.to_s, 0) } || "common"

    if combination_config&.dig(:rarity).present?
      rarity_key = combination_config[:rarity].to_s
    end

    rarity_info = palette[rarity_key] || {}

    {
      key: rarity_key,
      label: rarity_info[:label] || rarity_key.titleize,
      color: rarity_info[:color],
      score: RARITY_ORDER.fetch(rarity_key, 0),
      combination_key: combination_key
    }
  end
end
