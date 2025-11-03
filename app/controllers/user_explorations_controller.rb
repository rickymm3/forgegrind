class UserExplorationsController < ApplicationController
  before_action :set_user_exploration_for_panel, only: [:ready, :activate_encounter, :resolve_encounter, :checkpoint, :continue_segment]

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
    cooldown_until = Time.current + ExplorationGenerator::RESCOUT_COOLDOWN

    @user_exploration.destroy

    if generated
      generated.update!(cooldown_ends_at: cooldown_until, consumed_at: nil)
      generated.set_slot_state!(:cooldown)
      generated.set_reroll_cooldown!(nil)
    end

    refresh_slot_state(selected_generated: nil)

    respond_to do |format|
      format.turbo_stream
      format.html do
        redirect_to explorations_path,
                    notice: completion_notice
      end
    end
  end

  def ready
    respond_to do |format|
      format.turbo_stream do
        render_ready_streams(@user_exploration)
      end
    end
  end

  def checkpoint
    checkpoint = @user_exploration.mark_active_segment_checkpoint!
    checkpoint ||= @user_exploration.checkpoint_segment_entry
    if checkpoint.nil?
      head :unprocessable_entity and return
    end

    respond_to do |format|
      format.turbo_stream { render turbo_stream: zone_card_stream_for(@user_exploration, state: :checkpoint) }
      format.html do
        destination = @user_exploration.generated_exploration || @user_exploration.world
        redirect_to(destination.is_a?(GeneratedExploration) ? exploration_path(destination) : explorations_path)
      end
    end
  end

  def continue_segment
    unless @user_exploration.checkpoint_segment_entry
      head :unprocessable_entity and return
    end

    skip_encounter = ActiveModel::Type::Boolean.new.cast(params[:skip_encounter])
    next_segment = @user_exploration.continue_from_checkpoint!(skip_encounter: skip_encounter)
    @user_exploration.reload
    has_next_segment = next_segment.present?

    respond_to do |format|
      format.turbo_stream do
        if has_next_segment
          render turbo_stream: zone_card_stream_for(@user_exploration, state: :active)
        else
          render_ready_streams(@user_exploration)
        end
      end
      format.html do
        destination = @user_exploration.generated_exploration || @user_exploration.world
        redirect_to(destination.is_a?(GeneratedExploration) ? exploration_path(destination) : explorations_path,
                    notice: has_next_segment ? "Exploration resumed." : "Expedition ready to complete.")
      end
    end
  end

  def activate_encounter
    if @user_exploration.active_encounter?
      head :unprocessable_entity and return
    end

    @user_exploration.refresh_encounter_readiness!
    entry = @user_exploration.next_due_encounter
    if entry.blank?
      head :unprocessable_entity and return
    end

    expires_in = @user_exploration.available_encounter_timer_seconds(entry)
    @user_exploration.activate_encounter!(entry, expires_in: expires_in)
    @user_exploration.reload

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: zone_card_stream_for(@user_exploration, state: :checkpoint)
      end
      format.html do
        destination = @user_exploration.generated_exploration || @user_exploration.world
        redirect_to(destination.is_a?(GeneratedExploration) ? exploration_path(destination) : explorations_path,
                    notice: "Encounter triggered.")
      end
    end
  end

  def resolve_encounter
    unless @user_exploration.active_encounter?
      head :unprocessable_entity and return
    end

    choice_key = params[:choice_key].to_s
    options = @user_exploration.available_encounter_options
    option = options.find { |opt| opt[:key].to_s == choice_key }

    unless option
      head :unprocessable_entity and return
    end

    next_node = option[:next_node].presence
    outcome = option[:outcome]
    expires_in = @user_exploration.option_timer_seconds(option)
    completion_status = option[:status].presence || "completed"

    respond_to do |format|
      format.turbo_stream do
        if next_node
          @user_exploration.advance_active_encounter!(
            next_node: next_node,
            choice_key: choice_key,
            expires_in: expires_in,
            outcome: outcome
          )
          @user_exploration.reload
          render turbo_stream: zone_card_stream_for(@user_exploration, state: :checkpoint)
        else
          @user_exploration.complete_active_encounter!(
            choice_key: choice_key,
            outcome: outcome,
            status: completion_status
          )
          @user_exploration.reload
          render turbo_stream: zone_card_stream_for(@user_exploration, state: :checkpoint)
        end
      end
      format.html do
        if next_node
          notice = "Encounter progressed."
        else
          notice = "Encounter resolved."
        end
        if next_node
          @user_exploration.advance_active_encounter!(
            next_node: next_node,
            choice_key: choice_key,
            expires_in: expires_in,
            outcome: outcome
          )
        else
          @user_exploration.complete_active_encounter!(
            choice_key: choice_key,
            outcome: outcome,
            status: completion_status
          )
        end
        @user_exploration.reload
        destination = @user_exploration.generated_exploration || @user_exploration.world
        redirect_to(destination.is_a?(GeneratedExploration) ? exploration_path(destination) : explorations_path,
                    notice: notice)
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

  def render_ready_streams(user_exploration)
    streams = [zone_card_stream_for(user_exploration, state: :ready)]

    generated = user_exploration.generated_exploration
    if generated
      progress = generated.requirements_progress_for(user_exploration.user_pets)
      streams << turbo_stream.update(
        view_context.dom_id(generated, :card),
        partial: "explorations/world_tile",
        locals: {
          slot_index: generated.slot_index,
          generated_exploration: generated,
          requirement_progress: progress,
          requirement_groups: progress.group_by { |entry| entry[:source] || 'base' },
          selected: true,
          user_exploration: user_exploration,
          cooldown_seconds: generated.cooldown_remaining_seconds,
          cooldown_ends_at: generated.cooldown_ends_at,
          reroll_cooldown_seconds: generated.reroll_cooldown_remaining_seconds,
          reroll_available_at: generated.reroll_available_at
        }
      )
    end

    render turbo_stream: streams
  end

  def set_user_exploration_for_panel
    target_id = params[:id] || params[:user_exploration_id]
    raise ActiveRecord::RecordNotFound if target_id.blank?

    @user_exploration = current_user.user_explorations
                                    .includes(:generated_exploration, user_pets: [:pet, :learned_abilities])
                                    .find(target_id)
    @user_exploration.reload if @user_exploration.sync_segment_timers!
  end

  def zone_card_stream_for(user_exploration, state: nil)
    user_exploration.reload if user_exploration.sync_segment_timers!
    generated = user_exploration.generated_exploration
    render_generated = generated || GeneratedExploration.new(
      world: user_exploration.world,
      name: user_exploration.world.name,
      duration_seconds: user_exploration.duration_seconds,
      requirements: []
    )

    progress = if generated
                 generated.requirements_progress_for(user_exploration.user_pets)
               else
                 []
               end
    grouped = progress.group_by { |entry| entry[:source] || 'base' }
    detail_dom_id = view_context.dom_id(generated || user_exploration.world, :detail)
    resolved_state = state || inferred_zone_card_state(user_exploration)

    turbo_stream.update(
      detail_dom_id,
      partial: "explorations/zone_card",
      locals: {
        generated_exploration: render_generated,
        user_exploration: user_exploration,
        state: resolved_state,
        requirement_progress: progress,
        requirement_groups: grouped,
        available_pets: [],
        selected_pet_ids: [],
        filters: {}
      }
    )
  end

  def refresh_slot_state(selected_generated: nil)
    max_slots = ExplorationGenerator::DEFAULT_COUNT

    available_generated = current_user.generated_explorations
                                      .available
                                      .includes(world: :pet_types)
                                      .where(slot_index: 1..max_slots)
                                      .order(:slot_index, :created_at)
                                      .to_a
    available_generated.each(&:clear_reroll_cooldown_if_elapsed!)

    @active_explorations = current_user.user_explorations.includes(generated_exploration: { world: :pet_types }).where(completed_at: nil)
    existing_by_slot = available_generated.index_by(&:slot_index)
    active_by_slot = @active_explorations.each_with_object({}) do |exploration, memo|
      slot_index = exploration.generated_exploration&.slot_index
      memo[slot_index] = true if slot_index
    end

    generator = ExplorationGenerator.new(current_user)
    slot_range = 1..max_slots
    slots_to_refresh = []

    slot_range.each do |slot|
      generated = existing_by_slot[slot]
      next unless generated&.slot_state_sym == :cooldown
      next if generated.cooldown_active?

      slots_to_refresh << slot
      generated.destroy
      existing_by_slot.delete(slot)
    end

    available_generated.reject! { |gen| gen.slot_state_sym == :cooldown && !gen.cooldown_active? }

    slot_range.each do |slot|
      next if active_by_slot[slot]
      next if existing_by_slot[slot].present?

      slots_to_refresh << slot
    end

    slots_to_refresh.uniq.each do |slot|
      generator.generate!(slot_index: slot, force: true)
    end

    if slots_to_refresh.any?
      available_generated = current_user.generated_explorations
                                        .available
                                        .includes(world: :pet_types)
                                        .where(slot_index: 1..max_slots)
                                        .order(:slot_index, :created_at)
                                        .to_a
      available_generated.each(&:clear_reroll_cooldown_if_elapsed!)
    end

    @generated_explorations = available_generated.dup
    @active_explorations.each do |exploration|
      generated = exploration.generated_exploration
      next unless generated
      @generated_explorations << generated unless @generated_explorations.include?(generated)
    end
    @generated_explorations.uniq!

    @requirement_map = build_requirement_map(@generated_explorations)
    @active_explorations.each do |exploration|
      generated = exploration.generated_exploration
      next unless generated

      progress = generated.requirements_progress_for(exploration.user_pets)
      @requirement_map[generated.id] = {
        progress: progress,
        grouped: progress.group_by { |entry| entry[:source] || 'base' }
      }
    end

    selected = if selected_generated
                 selected_generated
               else
                 @generated_explorations.find { |gen| gen.slot_state_sym != :cooldown } || @generated_explorations.first
               end

    @slot_entries = Explorations::SlotLayoutBuilder.build(
      max_slots: max_slots,
      generated_explorations: @generated_explorations,
      active_explorations: @active_explorations,
      requirement_map: @requirement_map,
      selected_generated: selected
    )
  end

  def inferred_zone_card_state(user_exploration)
    return :selection unless user_exploration

    if user_exploration.active_encounter? || user_exploration.checkpoint_segment_entry.present?
      :checkpoint
    elsif user_exploration.complete?
      :ready
    else
      :active
    end
  end
end
