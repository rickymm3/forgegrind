class UserExploration < ApplicationRecord
  belongs_to :user
  belongs_to :world
  belongs_to :generated_exploration, optional: true
  has_and_belongs_to_many :user_pets,
                          -> { active },
                          join_table: "user_explorations_pets"
  belongs_to :primary_user_pet,
             class_name: "UserPet",
             optional: true

  validates :started_at, presence: true

  def timer_expired?
    if using_segments?
      segment_progress_entries.all? { |entry| segment_completed_status?(entry[:status]) }
    else
      Time.current >= started_at + duration_seconds.seconds
    end
  end

  def explore_time_remaining(reference_time: Time.current)
    remaining = duration_seconds - elapsed_seconds(reference_time: reference_time)
    [remaining, 0].max
  end

  def complete?
    timer_expired? && completed_at.nil?
  end

  def duration_seconds
    if generated_exploration.present?
      generated_exploration.duration_seconds
    else
      world.duration
    end
  end

  def using_segments?
    segment_progress_entries.any?
  end

  def segment_definitions
    generated_exploration&.segment_definitions || []
  end

  def segment_progress_entries
    Array(self[:segment_progress]).map do |entry|
      entry.respond_to?(:with_indifferent_access) ? entry.with_indifferent_access : entry
    end
  end

  def current_segment_index
    self[:current_segment_index].to_i
  end

  def active_segment_entry
    segment_progress_entries.find { |entry| entry[:status].to_s == 'active' }
  end

  def checkpoint_segment_entry
    segment_progress_entries.find { |entry| entry[:status].to_s == 'checkpoint' }
  end

  def next_segment_entry
    index = current_segment_index
    defs = segment_progress_entries.sort_by { |entry| entry[:index].to_i }
    defs.find { |entry| entry[:index].to_i > index }
  end

  def segment_duration(entry)
    entry.to_h[:duration_seconds].to_i
  end

  def segment_elapsed_seconds(entry, reference_time: Time.current)
    return segment_duration(entry) if segment_completed_status?(entry[:status])

    if entry[:status].to_s == 'active'
      start_time = segment_start_time(entry)
      return 0 unless start_time

      elapsed = [(reference_time - start_time).to_i, 0].max
      [elapsed, segment_duration(entry)].min
    else
      0
    end
  end

  def completed_segment_duration_seconds
    segment_progress_entries.sum do |entry|
      segment_completed_status?(entry[:status]) ? segment_duration(entry) : 0
    end
  end

  def active_segment_remaining_seconds(reference_time: Time.current)
    clock = active_segment_clock(reference_time: reference_time)
    clock ? clock[:remaining_seconds] : 0
  end

  def elapsed_seconds(reference_time: Time.current)
    if using_segments?
      total = 0
      segment_progress_entries.each do |entry|
        total += segment_elapsed_seconds(entry, reference_time: reference_time)
      end
      total
    else
      [(reference_time - started_at).to_i, 0].max
    end
  end

  def next_due_encounter(reference_time: Time.current)
    ready = ready_encounter_entry
    return ready if ready

    return nil if using_segments?

    current_elapsed = elapsed_seconds(reference_time: reference_time)
    pending_encounters
      .select { |entry| entry[:status].to_s != 'active' && entry[:offset_seconds].to_i <= current_elapsed }
      .min_by { |entry| entry[:offset_seconds].to_i }
  end

  def ready_encounter_entry
    encounter_schedule_entries
      .select { |entry| entry[:status].to_s == 'ready' }
      .min_by { |entry| entry[:segment_index].to_i }
  end

  def ready_encounter_segment_index
    ready_encounter_entry&.[](:segment_index)&.to_i
  end

  def upcoming_encounter_entry
    encounter_schedule_entries
      .select { |entry| entry[:status].to_s == 'pending' }
      .min_by { |entry| entry[:segment_index].to_i }
  end

  def checkpoint_completed_encounter_entry
    checkpoint = checkpoint_segment_entry
    return nil unless checkpoint

    encounter_schedule_entries.find do |entry|
      entry[:status].to_s == 'completed' && entry[:segment_index].to_i == checkpoint[:index].to_i
    end
  end

  def party_snapshot
    (self[:party_snapshot] || {}).with_indifferent_access
  end

  def ordered_user_pet_ids
    Array(party_snapshot[:ordered_user_pet_ids])
  end

  def party_members
    Array(party_snapshot[:members])
  end

  def party_requirements
    Array(party_snapshot[:requirements]).map do |entry|
      entry.respond_to?(:with_indifferent_access) ? entry.with_indifferent_access : entry
    end
  end

  def party_ability_refs
    party_members.flat_map { |entry| Array(entry[:special_ability_reference]) }.compact
  end

  def party_ability_tags
    party_members.flat_map { |entry| Array(entry[:special_ability_tags]) }.compact.uniq
  end

  def encounter_schedule
    Array(self[:encounter_schedule])
  end

  def encounter_schedule_entries
    encounter_schedule.map { |entry| entry.with_indifferent_access }
  end

  def pending_encounters
    encounter_schedule_entries.reject { |entry| %w[completed skipped].include?(entry[:status].to_s) }
  end

  def active_encounter_data
    (self[:active_encounter] || {}).with_indifferent_access
  end

  def active_encounter_slug
    value = active_encounter_data[:slug]
    value.present? ? value.to_s : nil
  end

  def active_encounter?
    active_encounter_slug.present?
  end

  def active_encounter_node
    encounter = active_encounter_data[:encounter]
    return nil unless encounter

    encounter = encounter.with_indifferent_access
    nodes = encounter[:nodes] || {}
    key = (active_encounter_data[:node_key] || 'intro').to_s
    nodes[key] || nodes[key.to_sym]
  end

  def active_encounter_title
    encounter = active_encounter_data[:encounter]
    encounter&.with_indifferent_access&.dig(:title) || active_encounter_data[:title]
  end

  def available_encounter_options
    node = active_encounter_node
    return [] unless node

    options = Array(node[:options]).map { |opt| opt.with_indifferent_access }
    options.select { |option| self.class.option_available?(option, party_ability_refs, party_ability_tags) }
  end

  def available_options_for_entry(entry, node_key: 'intro')
    entry = entry.with_indifferent_access
    encounter = entry[:encounter]
    nodes = encounter.present? ? encounter.with_indifferent_access[:nodes] : {}
    node = nodes.present? ? (nodes[node_key.to_s] || nodes[node_key.to_sym]) : nil
    return [] unless node

    options = Array(node[:options]).map { |opt| opt.with_indifferent_access }
    options.select { |option| self.class.option_available?(option, party_ability_refs, party_ability_tags) }
  end

  def activate_encounter!(entry, expires_in: nil)
    entry = entry.with_indifferent_access
    now = Time.current
    expires_at = expires_in.to_i.positive? ? now + expires_in.to_i : nil
    slug = entry[:slug]
    segment_index = entry[:segment_index]
    offset = entry[:offset_seconds].to_i

    updated_schedule = encounter_schedule_entries.map do |scheduled|
      matches_slug = scheduled[:slug] == slug
      matches_segment = if segment_index.present?
                          scheduled[:segment_index].to_i == segment_index.to_i
                        else
                          scheduled[:offset_seconds].to_i == offset
                        end
      if matches_slug && matches_segment && scheduled[:status].to_s == 'ready'
        scheduled.merge(status: 'active', activated_at: now)
      else
        scheduled
      end
    end

    payload = {
      slug: slug,
      segment_index: segment_index,
      node_key: entry[:node_key].presence || 'intro',
      encounter: entry[:encounter],
      options: entry[:options],
      history: [],
      started_at: now,
      expires_at: expires_at
    }

    update!(
      encounter_schedule: stringify_entries(updated_schedule),
      active_encounter: deep_stringify(payload),
      active_encounter_started_at: now,
      active_encounter_expires_at: expires_at
    )
  end

  def advance_active_encounter!(next_node:, choice_key:, expires_in: nil, outcome: nil)
    data = active_encounter_data
    history = Array(data[:history]).dup
    history << {
      node: data[:node_key] || 'intro',
      choice: choice_key,
      outcome: outcome,
      at: Time.current
    }

    payload = data.merge(
      node_key: next_node,
      history: history,
      expires_at: expires_in.to_i.positive? ? Time.current + expires_in.to_i : nil
    )

    update!(
      active_encounter: deep_stringify(payload),
      active_encounter_expires_at: payload[:expires_at]
    )
  end

  def complete_active_encounter!(choice_key: nil, outcome: nil, status: 'completed')
    slug = active_encounter_slug
    return unless slug

    now = Time.current
    data = active_encounter_data
    history = Array(data[:history]).dup
    history << {
      node: data[:node_key] || 'intro',
      choice: choice_key,
      outcome: outcome,
      at: now
    }

    segment_index = data[:segment_index] || encounter_schedule_entries.find { |scheduled| scheduled[:slug] == slug && scheduled[:status].to_s == 'active' }&.dig(:segment_index)

    updated_schedule = encounter_schedule_entries.map do |scheduled|
      matches_slug = scheduled[:slug] == slug
      matches_segment = segment_index.present? ? scheduled[:segment_index].to_i == segment_index.to_i : true

      if matches_slug && matches_segment && scheduled[:status].to_s == 'active'
        scheduled.merge(
          status: status,
          completed_at: now,
          outcome: outcome,
          history: history
        )
      else
        scheduled
      end
    end

    update!(
      encounter_schedule: stringify_entries(updated_schedule),
      active_encounter: {},
      active_encounter_started_at: nil,
      active_encounter_expires_at: nil
    )
  end

  def mark_active_segment_checkpoint!(reached_at: Time.current)
    segment = active_segment_entry
    return nil unless segment

    index = segment[:index].to_i
    updated_segments = segment_progress_entries.map do |entry|
      if entry[:index].to_i == index
        entry.merge(status: 'checkpoint', reached_at: reached_at)
      else
        entry
      end
    end

    attrs = {
      segment_progress: stringify_entries(updated_segments),
      current_segment_index: index,
      segment_started_at: nil
    }

    transaction do
      update!(attrs)
      mark_encounters_ready_for_segment!(index, ready_at: reached_at)
    end

    checkpoint_segment_entry
  end

  def mark_encounters_ready_for_segment!(segment_index, ready_at: Time.current)
    changed = false
    updated_schedule = encounter_schedule_entries.map do |entry|
      if entry[:segment_index].to_i == segment_index.to_i && entry[:status].to_s == 'pending'
        changed = true
        entry.merge(status: 'ready', ready_at: ready_at)
      else
        entry
      end
    end

    return unless changed

    update!(encounter_schedule: stringify_entries(updated_schedule))
  end

  def skip_ready_encounters_for_segment!(segment_index, skipped_at: Time.current)
    changed = false
    updated_schedule = encounter_schedule_entries.map do |entry|
      if entry[:segment_index].to_i == segment_index.to_i && entry[:status].to_s == 'ready'
        changed = true
        entry.merge(status: 'skipped', completed_at: skipped_at)
      else
        entry
      end
    end

    return unless changed

    update!(encounter_schedule: stringify_entries(updated_schedule))
  end

  def continue_from_checkpoint!(skip_encounter: false, resumed_at: Time.current)
    checkpoint = checkpoint_segment_entry
    return nil unless checkpoint

    index = checkpoint[:index].to_i
    skip_ready_encounters_for_segment!(index, skipped_at: resumed_at) if skip_encounter

    updated_segments = segment_progress_entries.map do |entry|
      case entry[:index].to_i
      when index
        entry.merge(status: 'completed', completed_at: resumed_at)
      when index + 1
        if entry[:status].to_s == 'upcoming'
          entry.merge(status: 'active', reached_at: resumed_at, completed_at: nil)
        else
          entry
        end
      else
        entry
      end
    end

    next_segment = updated_segments.find { |entry| entry[:index].to_i == index + 1 && entry[:status].to_s == 'active' }

    attrs = {
      segment_progress: stringify_entries(updated_segments),
      current_segment_index: next_segment ? next_segment[:index].to_i : index,
      segment_started_at: next_segment ? resumed_at : nil
    }

    update!(attrs)
    refresh_encounter_readiness!
    next_segment
  end

  def active_segment_clock(reference_time: Time.current)
    entry = active_segment_entry
    return nil unless entry

    start_time = segment_start_time(entry)
    return nil unless start_time

    duration = segment_duration(entry)
    elapsed = [(reference_time - start_time).floor, 0].max
    elapsed = [elapsed, duration].min
    remaining = duration - elapsed
    end_time = start_time + duration.seconds

    {
      entry: entry,
      duration_seconds: duration,
      start_time: start_time,
      end_time: end_time,
      remaining_seconds: remaining,
      elapsed_seconds: elapsed
    }
  end

  def sync_segment_timers!(reference_time: Time.current)
    return false unless using_segments?

    changed = false

    loop do
      clock = active_segment_clock(reference_time: reference_time)
      break unless clock

      break if clock[:remaining_seconds].positive?

      mark_active_segment_checkpoint!(reached_at: clock[:end_time])
      reload
      changed = true
    end

    changed
  end

  def active_encounter_expired?(reference_time: Time.current)
    return false unless active_encounter_expires_at
    reference_time >= active_encounter_expires_at
  end

  def option_timer_seconds(option)
    seconds = option[:timer_seconds].to_i
    seconds.positive? ? seconds : nil
  end

  def available_encounter_timer_seconds(entry)
    options = available_options_for_entry(entry)
    timers = options.filter_map { |option| option_timer_seconds(option) }
    timers.min
  end

  def option_available?(option)
    self.class.option_available?(option, party_ability_refs, party_ability_tags)
  end

  def auto_trigger_due_encounter!(reference_time: Time.current)
    refresh_encounter_readiness!
    false
  end

  def refresh_encounter_readiness!
    return unless using_segments?

    checkpoint_indices = segment_progress_entries.select { |entry| entry[:status].to_s == 'checkpoint' }
                                                 .map { |entry| entry[:index].to_i }
    return if checkpoint_indices.empty?

    changed = false
    updated_schedule = encounter_schedule_entries.map do |entry|
      if checkpoint_indices.include?(entry[:segment_index].to_i) && entry[:status].to_s == 'pending'
        changed = true
        entry.merge(status: 'ready', ready_at: Time.current)
      else
        entry
      end
    end

    update!(encounter_schedule: stringify_entries(updated_schedule)) if changed
  end

  def self.option_available?(option, ability_refs, ability_tags)
    option = option.with_indifferent_access
    requirements = option[:requires]
    return true if requirements.blank?

    required_refs = Array(requirements[:special_abilities]).map(&:to_s)
    required_tags = Array(requirements[:special_ability_tags]).map(&:to_s)

    refs_ok = required_refs.blank? || (ability_refs & required_refs).any?
    tags_ok = required_tags.blank? || (ability_tags & required_tags).any?
    refs_ok && tags_ok
  end

  private

  def stringify_entries(entries)
    entries.map { |entry| deep_stringify(entry) }
  end

  def segment_start_time(entry)
    parse_time_value(entry[:reached_at]) || segment_started_at || started_at
  end

  def parse_time_value(value)
    return value if value.is_a?(Time)
    return nil if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def deep_stringify(object)
    case object
    when Hash
      object.each_with_object({}) { |(k, v), memo| memo[k.to_s] = deep_stringify(v) }
    when Array
      object.map { |v| deep_stringify(v) }
    else
      object
    end
  end

  def segment_completed_status?(status)
    %w[completed checkpoint].include?(status.to_s)
  end
end
