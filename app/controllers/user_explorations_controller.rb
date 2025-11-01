class UserExplorationsController < ApplicationController
  def complete
    @user_exploration = current_user.user_explorations.includes(:generated_exploration, user_pets: [:pet, :learned_abilities]).find(params[:id])
    generated = @user_exploration.generated_exploration
    @world = @user_exploration.world

    reward_config = ExplorationRewards.for(@world)
    outcome = ExplorationOutcome.evaluate(world: @world, user_pets: @user_exploration.user_pets)

    @reward = adjusted_reward(reward_config.exp, outcome.reward_multiplier)
    @diamond_reward = adjusted_reward(reward_config.diamonds, outcome.diamond_multiplier)
    @trophy_reward = rand(50..100)

    @user_pets = @user_exploration.user_pets.to_a
    apply_experience_and_needs!(@user_pets, @user_exploration.duration_seconds, outcome.need_penalty_multiplier)

    stat = current_user.user_stat || current_user.create_user_stat!(User::STAT_DEFAULTS.merge(energy_updated_at: Time.current))
    stat.increment!(:trophies, @trophy_reward)
    stat.increment!(:diamonds, @diamond_reward) if @diamond_reward.positive?
    @user_stats = stat.reload

    reward_result = Explorations::ExplorationCompletionRewarder.call(user: current_user, world: @world)
    @granted_chest_type = reward_result[:chest_type]
    @granted_container = reward_result[:user_container]

    @generated_snapshot = generated
    @user_exploration.destroy
    generated&.destroy

    @generated_explorations = current_user.generated_explorations.available.includes(world: :pet_types).order(:created_at)
    @requirement_map = build_requirement_map(@generated_explorations)
    @active_explorations = current_user.user_explorations.includes(:generated_exploration).where(completed_at: nil)

    respond_to do |format|
      format.turbo_stream
      format.html do
        redirect_to explorations_path,
                    notice: completion_notice
      end
    end
  end

  def ready
    @user_exploration = current_user.user_explorations.includes(:generated_exploration, user_pets: [:pet, :learned_abilities]).find(params[:id] || params[:user_exploration_id])
    generated = @user_exploration.generated_exploration
    progress = generated&.requirements_progress_for(@user_exploration.user_pets) || []

    respond_to do |format|
      format.turbo_stream do
        detail_dom_id = view_context.dom_id(generated || @user_exploration.world, :detail)
        render turbo_stream: turbo_stream.update(
          detail_dom_id,
          partial: "explorations/zone_card",
          locals: {
            generated_exploration: generated || GeneratedExploration.new(world: @user_exploration.world, name: @user_exploration.world.name, duration_seconds: @user_exploration.duration_seconds, requirements: []),
            user_exploration: @user_exploration,
            state: :ready,
            requirement_progress: progress,
            requirement_groups: progress.group_by { |entry| entry[:source] || 'base' },
            available_pets: [],
            selected_pet_ids: [],
            filters: {}
          }
        )
      end
    end
  end

  private

  def completion_notice
    base = "Exploration complete! Each pet gained #{@reward} EXP."
    trophy_text = " You earned #{@trophy_reward} Trophies."
    base += trophy_text
    return base unless @diamond_reward.to_i.positive?

    "#{base} You earned #{@diamond_reward} Diamonds."
  end

  def adjusted_reward(base_value, multiplier)
    value = (base_value.to_f * multiplier.to_f).round
    [value, 0].max
  end

  def apply_experience_and_needs!(user_pets, duration_seconds, penalty_multiplier)
    user_pets.each do |pet|
      new_exp = [pet.exp.to_i + @reward, UserPet::EXP_PER_LEVEL].min
      pet.assign_attributes(exp: new_exp)
      apply_exploration_need_penalties!(pet, duration_seconds, penalty_multiplier)
      pet.save!(validate: false)
    end
  end

  def apply_exploration_need_penalties!(user_pet, duration_seconds, penalty_multiplier)
    penalties = base_need_penalties(duration_seconds)

    penalties.each do |attr, delta|
      current = user_pet.send(attr).to_f
      adjusted_delta = (delta * penalty_multiplier).round
      updated = user_pet.send(:clamp_need, current + adjusted_delta)
      user_pet.send("#{attr}=", updated)
    end

    user_pet.needs_updated_at = Time.current
    user_pet.recalc_mood!(save: false)
  end

  def base_need_penalties(duration_seconds)
    duration_minutes = duration_seconds.to_i / 60.0
    difficulty = if duration_minutes < 15
                   :easy
                 elsif duration_minutes >= 45
                   :hard
                 else
                   :normal
                 end

    case difficulty
    when :easy
      { hunger: -8, hygiene: -6, boredom: -12, mood: -6, injury_level: 4 }
    when :hard
      { hunger: -18, hygiene: -12, boredom: -24, mood: -14, injury_level: 10 }
    else
      { hunger: -12, hygiene: -8, boredom: -18, mood: -10, injury_level: 6 }
    end
  end

  def build_requirement_map(generated_list)
    generated_list.each_with_object({}) do |generated, memo|
      progress = generated.requirements_progress_for([])
      memo[generated.id] = {
        progress: progress,
        grouped: progress.group_by { |entry| entry[:source] || 'base' }
      }
    end
  end
end
