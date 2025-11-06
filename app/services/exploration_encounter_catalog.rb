class ExplorationEncounterCatalog
  ENCOUNTERS_PATH     = Rails.root.join("config", "explorations", "encounters.yml")
  WORLD_PROFILES_PATH = Rails.root.join("config", "explorations", "world_profiles.yml")

  BASE_ENCOUNTER_CHANCE  = 0.35
  BONUS_ENCOUNTER_CHANCE = 0.45
  MAX_ENCOUNTER_CHANCE   = 0.9

  class << self
    def schedule_for(world:, duration:, ability_refs: [], ability_tags: [], count: nil, seed: nil, requirements: [], fulfilled_ids: [], segments: nil)
      profile = world_profile(world)
      count ||= profile.fetch("default_encounter_count", 0).to_i
      count = 0 if count.negative?

      ability_refs = normalize_array(ability_refs)
      ability_tags = normalize_array(ability_tags)
      requirements = Array(requirements)
      fulfilled_ids = Array(fulfilled_ids).map(&:to_s)

      candidates = encounters_for(world: world, ability_refs: ability_refs, ability_tags: ability_tags)
      return [] if candidates.empty?

      requirement_context = build_requirement_context(requirements, fulfilled_ids)
      pool = build_weighted_pool(candidates, requirement_context)
      probability = encounter_probability(requirement_context[:fulfilled_ratio])
      random = Random.new(seed || Random.new_seed)

      segment_entries = normalize_segments_for_schedule(segments)

      if segment_entries.present?
        eligible_segments = segment_entries.select { |segment| segment_allows_encounters?(segment) }
        return [] if eligible_segments.empty?

        max_entries = count.positive? ? [count, eligible_segments.size].min : 0
        return [] if max_entries <= 0

        build_segment_schedule(
          eligible_segments,
          pool: pool,
          random: random,
          probability: probability,
          ability_refs: ability_refs,
          ability_tags: ability_tags,
          max_entries: max_entries
        )
      else
        return [] if count.zero? || duration.to_i <= 0

        build_interval_schedule(
          count,
          duration,
          pool: pool,
          random: random,
          probability: probability,
          ability_refs: ability_refs,
          ability_tags: ability_tags
        )
      end
    end

    def encounters_for(world:, ability_refs: [], ability_tags: [])
      ability_refs = normalize_array(ability_refs)
      ability_tags = normalize_array(ability_tags)
      tags = world_tags(world)
      slug = world_slug(world)

      encountered = base_encounters(tags) + world_specific_encounters(slug)
      unique_by_slug(encountered).select do |encounter|
        requirements_met?(requirements_from(encounter), ability_refs, ability_tags)
      end
    end

    def world_profile(world)
      slug = world_slug(world)
      default_profile = world_profiles.fetch("default", {})
      specific = world_profiles.fetch(slug, {})
      deep_merge(default_profile, specific)
    end

    def world_tags(world)
      Array(world_profile(world).fetch("tags", [])).presence || [world_slug(world)]
    end

    def reload!
      @encounters = nil
      @world_profiles = nil
    end

    private

    def encounters
      @encounters ||= load_yaml(ENCOUNTERS_PATH)
    end

    def world_profiles
      @world_profiles ||= load_yaml(WORLD_PROFILES_PATH)
    end

    def base_encounters(tags)
      global = Array(encounters.fetch("global", []))
      tag_set = normalize_array(tags)
      global.select do |encounter|
        encounter_tags = normalize_array(encounter["world_tags"])
        encounter_tags.blank? || (encounter_tags & tag_set).any?
      end
    end

    def world_specific_encounters(slug)
      Array(encounters.dig("worlds", slug))
    end

    def build_requirement_context(requirements, fulfilled_ids)
      all_tags = []
      fulfilled_tags = []

      Array(requirements).each do |raw_req|
        req = raw_req.respond_to?(:with_indifferent_access) ? raw_req.with_indifferent_access : raw_req
        tags = requirement_tags_for(req)
        all_tags.concat(tags)
        fulfilled_tags.concat(tags) if fulfilled_ids.include?(req[:id].to_s)
      end

      total = requirements.size
      ratio = total.positive? ? (fulfilled_ids.size.to_f / total) : 0.0

      {
        total: total,
        fulfilled_ratio: ratio.clamp(0.0, 1.0),
        all_tags: all_tags.uniq,
        fulfilled_tags: fulfilled_tags.uniq
      }
    end

    def build_weighted_pool(candidates, context)
      candidates.map do |encounter|
        base_weight = encounter.fetch("base_weight", 1.0).to_f
        base_weight = 0.01 if base_weight <= 0

        tags = normalize_array(encounter["requirement_tags"])
        multiplier = if tags.any?
                       fulfilled_matches = (tags & context[:fulfilled_tags]).size
                       partial_matches = (tags & context[:all_tags]).size
                       1.0 + fulfilled_matches * 0.5 + partial_matches * 0.25
                     else
                       1.0 + context[:fulfilled_ratio] * 0.25
                     end
        multiplier = 0.1 if multiplier <= 0
        { encounter: encounter, weight: base_weight * multiplier }
      end
    end

    def pick_weighted(pool, random, indices: nil)
      candidates =
        if indices
          indices.map { |idx| [pool[idx], idx] }
        else
          pool.each_with_index.map { |entry, idx| [entry, idx] }
        end

      total = candidates.sum { |entry, _idx| entry[:weight] }
      return [nil, pool] if total <= 0

      target = random.rand * total
      running = 0.0
      chosen_index = nil

      candidates.each do |entry, original_index|
        running += entry[:weight]
        if target <= running
          chosen_index = original_index
          break
        end
      end

      chosen_index ||= candidates.last&.last
      return [nil, pool] unless chosen_index

      entry = pool.delete_at(chosen_index)
      [entry[:encounter], pool]
    end

    def encounter_probability(fulfilled_ratio)
      base = configured_chance(:exploration_base_encounter_chance, BASE_ENCOUNTER_CHANCE)
      bonus = configured_chance(:exploration_bonus_encounter_chance, BONUS_ENCOUNTER_CHANCE)
      max = configured_chance(:exploration_max_encounter_chance, MAX_ENCOUNTER_CHANCE)
      (base + fulfilled_ratio * bonus).clamp(0.0, max)
    end

    def build_schedule_entry(encounter, offset_seconds:, ability_refs:, ability_tags:, segment: nil)
      options = available_options_for(encounter, ability_refs: ability_refs, ability_tags: ability_tags)
      payload = {
        "slug" => encounter.fetch("slug"),
        "offset_seconds" => offset_seconds,
        "status" => "pending",
        "encounter" => deep_stringify(encounter),
        "options" => deep_stringify(options)
      }
      return payload if segment.blank?

      segment = segment.with_indifferent_access
      payload.merge(
        "segment_index" => segment[:index],
        "segment_key" => segment[:key],
        "segment_label" => segment[:label],
        "checkpoint_offset_seconds" => segment[:checkpoint_offset_seconds],
        "segment_duration_seconds" => segment[:duration_seconds]
      )
    end

    def available_options_for(encounter, ability_refs:, ability_tags:)
      defaults = Array(encounter.dig("options", "default"))
      unlocked = Array(encounter.dig("options", "ability_unlocks")).select do |option|
        requirements_met?(requirements_from(option), ability_refs, ability_tags)
      end
      (defaults + unlocked).map { |option| deep_dup(option) }
    end

    def requirements_from(node)
      return {} unless node.is_a?(Hash)
      raw = node["requirements"] || node[:requirements] || node["requires"] || node[:requires]
      raw || {}
    end

    def requirements_met?(requirements, ability_refs, ability_tags)
      return true if requirements.blank?

      requirements = requirements.deep_stringify_keys if requirements.respond_to?(:deep_stringify_keys)
      required_refs = normalize_array(requirements["special_abilities"])
      required_tags = normalize_array(requirements["special_ability_tags"])

      return false if required_refs.present? && (ability_refs & required_refs).empty?
      return false if required_tags.present? && (ability_tags & required_tags).empty?

      true
    end

    def build_segment_schedule(segments, pool:, random:, probability:, ability_refs:, ability_tags:, max_entries:)
      pool = pool.map(&:dup)
      entries = []

      segments.each do |segment|
        break if max_entries.positive? && entries.size >= max_entries
        next unless segment_allows_encounters?(segment)

        segment_probability = adjust_segment_probability(probability, segment[:encounter_probability_multiplier])
        next unless random.rand < segment_probability

        indices = segment_pool_indices(pool, segment)
        next if indices&.empty?

        encounter, pool = pick_weighted(pool, random, indices: indices)
        next unless encounter

        offset = segment[:checkpoint_offset_seconds]
        offset = segment[:offset_seconds] if offset.nil?
        offset = segment[:duration_seconds] if offset.nil?
        offset = offset.to_i
        offset = 0 if offset.negative?

        entries << build_schedule_entry(
          encounter,
          offset_seconds: offset,
          ability_refs: ability_refs,
          ability_tags: ability_tags,
          segment: segment
        )

        break if pool.empty?
      end

      entries
    end

    def build_interval_schedule(count, duration, pool:, random:, probability:, ability_refs:, ability_tags:)
      pool = pool.map(&:dup)
      selected = []

      count.times do
        break if pool.empty?
        next unless random.rand < probability

        encounter, pool = pick_weighted(pool, random)
        selected << encounter if encounter
      end

      return [] if selected.empty?

      interval = duration.to_f / (selected.size + 1)
      selected.each_with_index.map do |encounter, index|
        offset_seconds = (interval * (index + 1)).round
        build_schedule_entry(
          encounter,
          offset_seconds: offset_seconds,
          ability_refs: ability_refs,
          ability_tags: ability_tags
        )
      end
    end

    def normalize_segments_for_schedule(raw_segments)
      segments = Array(raw_segments).compact
      return [] if segments.empty?

      running_offset = 0

      segments.map.with_index do |segment, idx|
        data = segment.respond_to?(:with_indifferent_access) ? segment.with_indifferent_access : segment

        index = data[:index]
        index = index.to_i if index.present?
        index = idx if index.nil?

        duration = data[:duration_seconds].to_i
        duration = 1 if duration <= 0

        running_offset += duration
        checkpoint_offset = if data.key?(:checkpoint_offset_seconds)
                              value = data[:checkpoint_offset_seconds]
                              value.nil? ? nil : value.to_i
                            else
                              nil
                            end
        checkpoint_offset = running_offset if checkpoint_offset.nil?

        data.merge(
          index: index,
          duration_seconds: duration,
          checkpoint_offset_seconds: checkpoint_offset
        )
      end
    end

    def segment_allows_encounters?(segment)
      return false if segment[:allow_encounters] == false
      return false if segment[:encounters_enabled] == false
      true
    end

    def segment_pool_indices(pool, segment)
      tags = normalize_array(segment[:encounter_tags])
      slugs = normalize_array(segment[:encounter_slugs])
      return nil if tags.blank? && slugs.blank?

      pool.each_with_index.each_with_object([]) do |(entry, idx), acc|
        encounter = entry[:encounter]
        slug = encounter["slug"].to_s
        next if slugs.present? && !slugs.include?(slug)

        if tags.present?
          encounter_tags = encounter_tags_for(encounter)
          next if (encounter_tags & tags).empty?
        end

        acc << idx
      end
    end

    def adjust_segment_probability(base_probability, multiplier)
      return base_probability if multiplier.nil?

      (base_probability.to_f * multiplier.to_f).clamp(0.0, 1.0)
    end

    def encounter_tags_for(encounter)
      world_tags = normalize_array(encounter["world_tags"])
      req_tags   = normalize_array(encounter["requirement_tags"])
      misc_tags  = normalize_array(encounter["tags"])
      (world_tags + req_tags + misc_tags).uniq
    end

    def unique_by_slug(encounters)
      encounters.each_with_object({}) do |encounter, memo|
        slug = encounter["slug"]
        memo[slug] ||= encounter if slug.present?
      end.values
    end

    def configured_chance(key, fallback)
      config = Rails.application.config
      return fallback unless config.respond_to?(key)

      value = config.public_send(key)
      return fallback unless value.present?

      value.to_f
    rescue StandardError
      fallback
    end

    def deep_dup(object)
      case object
      when Hash
        object.each_with_object({}) { |(k, v), memo| memo[k] = deep_dup(v) }
      when Array
        object.map { |v| deep_dup(v) }
      else
        object.dup rescue object
      end
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

    def deep_merge(base, override)
      return base unless base.is_a?(Hash)
      return override unless override.is_a?(Hash)

      base.deep_merge(override)
    end

    def load_yaml(path)
      return {} unless path.exist?
      YAML.load_file(path) || {}
    rescue Psych::SyntaxError => e
      Rails.logger.error("Failed to load #{path}: #{e.message}")
      {}
    end

    def normalize_array(value)
      Array(value).map(&:to_s).reject(&:blank?)
    end

    def world_slug(world)
      case world
      when World
        world.exploration_slug
      else
        world.to_s.parameterize(separator: '-')
      end
    end

    def requirement_tags_for(requirement)
      tags = []
      source = requirement[:source].to_s
      type   = requirement[:type].to_s
      key    = requirement[:key] || requirement[:value]

      if source.present?
        tags << source
        tags << "source:#{source}"
      end

      if type.present?
        tags << type
        tags << "type:#{type}"
      end

      if key.present?
        normalized = key.to_s.parameterize
        tags << normalized
        tags << "key:#{normalized}"
        tags << "#{type}:#{normalized}" if type.present?
      end

      tags
    end
  end
end
