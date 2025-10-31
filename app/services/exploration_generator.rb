class ExplorationGenerator
  DEFAULT_COUNT = 3
  RESCOUT_COOLDOWN = 10.minutes

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

  def generate!(count: DEFAULT_COUNT, force: false)
    ActiveRecord::Base.transaction do
      user.lock!
      ensure_cooldown!(force)

      slots = [count.to_i - active_exploration_count, 0].max
      user.update!(last_scouted_at: Time.current)
      user.generated_explorations.available.destroy_all

      slots.times { create_generated_exploration }
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

  def active_exploration_count
    user.user_explorations.where(completed_at: nil).count
  end

  def create_generated_exploration
    base_key, base_config = ExplorationModLibrary.sample_base
    prefix_key, prefix_config = ExplorationModLibrary.sample_prefix
    suffix_key, suffix_config = ExplorationModLibrary.sample_suffix

    world = resolve_world(base_config)
    duration = compute_duration(base_config, prefix_config, suffix_config)
    name = build_name(base_config, prefix_config, suffix_config)
    requirements = merge_requirements(
      [base_config, 'base'],
      [prefix_config, 'prefix'],
      [suffix_config, 'suffix']
    )
    reward_config = merge_rewards(
      [base_config, 'base'],
      [prefix_config, 'prefix'],
      [suffix_config, 'suffix']
    )
    metadata = build_metadata(base_config, prefix_config, suffix_config)

    user.generated_explorations.create!(
      world: world,
      base_key: base_key,
      prefix_key: prefix_key,
      suffix_key: suffix_key,
      name: name,
      duration_seconds: duration,
      requirements: requirements,
      reward_config: reward_config,
      metadata: metadata,
      scouted_at: Time.current,
      expires_at: Time.current.end_of_day
    )
  end

  def resolve_world(base_config)
    world_name = base_config[:world_name] || base_config['world_name']
    World.find_by(name: world_name) || World.active.first || raise(ActiveRecord::RecordNotFound, "World not found for base #{world_name}")
  end

  def compute_duration(*configs)
    base_config = configs[0]
    duration = base_config[:default_duration].to_i
    multiplier = 1.0
    additive = 0

    configs.each do |config|
      next unless config

      multiplier *= config[:duration_multiplier].to_f if config[:duration_multiplier]
      additive += config[:duration_bonus].to_i if config[:duration_bonus]
    end

    [(duration * multiplier).to_i + additive, 300].max
  end

  def build_name(base_config, prefix_config, suffix_config)
    parts = []
    parts << prefix_config[:label] if prefix_config && prefix_config[:label]
    parts << base_config[:label]
    parts << suffix_config[:label] if suffix_config && suffix_config[:label]
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

  def build_metadata(*configs)
    {
      flavor: configs.compact.map { |conf| conf[:flavor] }.compact
    }
  end

  def ensure_cooldown!(force)
    return if force

    remaining = self.class.cooldown_remaining_for(user)
    raise CooldownNotElapsedError.new(remaining) if remaining.positive?
  end
end
