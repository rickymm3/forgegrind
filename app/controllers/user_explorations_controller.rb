class UserExplorationsController < ApplicationController
  before_action :set_user_exploration_for_panel, only: [:ready, :activate_encounter, :resolve_encounter, :checkpoint, :continue_segment]

  def complete
    @user_exploration = current_user.user_explorations.includes(:generated_exploration, user_pets: [:pet, :learned_abilities]).find(params[:id])
    generated = @user_exploration.generated_exploration
    @world = @user_exploration.world

    drop_keys = generated&.reward_drop_keys || []
    reward_summary = ExplorationRewards.for_drop_keys(drop_keys, fallback_world: @world)
    outcome = ExplorationOutcome.evaluate(world: @world, user_pets: @user_exploration.user_pets)

    @reward = adjusted_reward(reward_summary.exp, outcome.reward_multiplier)
    @diamond_reward = adjusted_reward(reward_summary.diamonds, outcome.diamond_multiplier)
    @coin_reward = 0

    @user_pets = @user_exploration.user_pets.to_a
    @leader_pet = @user_pets.find { |pet| pet.id == @user_exploration.primary_user_pet_id }
    apply_experience_and_needs!(@user_pets, @user_exploration.duration_seconds, outcome.need_penalty_multiplier)
    @user_pets.each { |pet| pet.ensure_sleep_state! }
    refresh_pet_state(@leader_pet) if @leader_pet.present?
    @leader_slot_dom_id = if @leader_pet&.active_slot.present?
                            helpers.pet_slot_dom_id(@leader_pet, @leader_pet.active_slot)
                          end

    diamonds_currency = Currency.find_by_key(:diamonds)

    if @diamond_reward.positive?
      if diamonds_currency
        current_user.credit_currency!(diamonds_currency, @diamond_reward)
      else
        Rails.logger.warn("[Explorations] Diamonds currency missing, reward not granted.")
      end
    end
    @currency_balances = helpers.currency_balances_for(current_user)

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
      if @user_exploration.segment_progress_entries.all? { |entry| entry[:status].to_s == 'completed' } && @user_exploration.complete?
        respond_to do |format|
          format.turbo_stream do
            render_ready_streams(@user_exploration)
          end
          format.html do
            destination = @user_exploration.generated_exploration || @user_exploration.world
            redirect_to(destination.is_a?(GeneratedExploration) ? zone_explorations_path(id: destination.id) : explorations_path)
          end
        end
        return
      end

      head :unprocessable_entity and return
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [zone_card_stream_for(@user_exploration, state: :checkpoint), nav_tabbar_stream]
      end
      format.html do
        destination = @user_exploration.generated_exploration || @user_exploration.world
        redirect_to(destination.is_a?(GeneratedExploration) ? zone_explorations_path(id: destination.id) : explorations_path)
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
          render turbo_stream: [zone_card_stream_for(@user_exploration, state: :active), nav_tabbar_stream]
        else
          render_ready_streams(@user_exploration)
        end
      end
      format.html do
        destination = @user_exploration.generated_exploration || @user_exploration.world
        redirect_to(destination.is_a?(GeneratedExploration) ? zone_explorations_path(id: destination.id) : explorations_path,
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

    expires_in = if entry[:segment_index].present?
                   nil
                 else
                   @user_exploration.available_encounter_timer_seconds(entry)
                 end
    @user_exploration.activate_encounter!(entry, expires_in: expires_in)
    @user_exploration.reload

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [zone_card_stream_for(@user_exploration, state: :checkpoint), nav_tabbar_stream]
      end
      format.html do
        destination = @user_exploration.generated_exploration || @user_exploration.world
        redirect_to(destination.is_a?(GeneratedExploration) ? zone_explorations_path(id: destination.id) : explorations_path,
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

    success_config = option[:success].is_a?(Hash) ? option[:success].with_indifferent_access : {}
    failure_config = option[:failure].is_a?(Hash) ? option[:failure].with_indifferent_access : {}

    success_next_node = success_config[:next_node].presence || option[:next_node].presence
    failure_next_node = failure_config[:next_node].presence || option[:failure_next_node].presence
    default_outcome = option[:outcome]
    success_outcome = success_config[:outcome].presence || default_outcome
    failure_outcome = failure_config[:outcome].presence || option[:failure_outcome].presence || "#{option[:key]}_failed"
    success_status = success_config[:status].presence || option[:status].presence || "completed"
    failure_status = failure_config[:status].presence || option[:failure_status].presence || "failed"
    expires_in = @user_exploration.option_timer_seconds(option)
    chance_data = @user_exploration.success_chance_for_option(option)
    chance_value = chance_data&.[](:chance)
    roll_value = chance_value.present? ? rand : nil
    success = chance_value.nil? ? true : roll_value <= chance_value

    target_next_node = success ? success_next_node : failure_next_node
    target_outcome = success ? success_outcome : failure_outcome
    target_status = success ? success_status : failure_status

    respond_to do |format|
      format.turbo_stream do
        if target_next_node.present?
          @user_exploration.advance_active_encounter!(
            next_node: target_next_node,
            choice_key: choice_key,
            expires_in: expires_in,
            outcome: target_outcome
          )
          @user_exploration.reload
          render turbo_stream: [zone_card_stream_for(@user_exploration, state: :checkpoint), nav_tabbar_stream]
        else
          @user_exploration.complete_active_encounter!(
            choice_key: choice_key,
            outcome: target_outcome,
            status: target_status,
            chance: chance_value,
            roll: roll_value
          )
          @user_exploration.reload
          render turbo_stream: [zone_card_stream_for(@user_exploration, state: :checkpoint), nav_tabbar_stream]
        end
      end
      format.html do
        notice =
          if target_next_node.present?
            "Encounter progressed."
          elsif success
            "Encounter resolved."
          else
            "Encounter failed."
          end

        if target_next_node.present?
          @user_exploration.advance_active_encounter!(
            next_node: target_next_node,
            choice_key: choice_key,
            expires_in: expires_in,
            outcome: target_outcome
          )
        else
          @user_exploration.complete_active_encounter!(
            choice_key: choice_key,
            outcome: target_outcome,
            status: target_status,
            chance: chance_value,
            roll: roll_value
          )
        end
        @user_exploration.reload
        destination = @user_exploration.generated_exploration || @user_exploration.world
        redirect_to(destination.is_a?(GeneratedExploration) ? zone_explorations_path(id: destination.id) : explorations_path,
                    notice: notice)
      end
    end
  end

  private

  def completion_notice
    base = "Exploration complete! Each pet gained #{@reward} EXP."
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

  def refresh_pet_state(pet)
    return unless pet

    ticks = pet.catch_up_energy!
    pet.catch_up_needs!(care_ticks: ticks)
    pet.accrue_held_coins!
    pet.ensure_sleep_state!
    PetThoughtRefresher.refresh!(pet)
    PetRequestService.new(pet).refresh_request!
    pet.save!(validate: false)
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

    streams << nav_tabbar_stream
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
        filters: {},
        show_filters: false,
        compact_layout: true
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

    slot_range = 1..max_slots

    slot_range.each do |slot|
      generated = existing_by_slot[slot]
      next unless generated&.slot_state_sym == :cooldown
      next if generated.cooldown_active?

      generated.destroy
      existing_by_slot.delete(slot)
    end

    available_generated.reject! { |gen| gen.slot_state_sym == :cooldown && !gen.cooldown_active? }

    if current_user.last_scouted_at.nil? && available_generated.empty?
      ExplorationGenerator.new(current_user).generate!(force: true)
      available_generated = current_user.generated_explorations
                                        .available
                                        .includes(world: :pet_types)
                                        .where(slot_index: 1..max_slots)
                                        .order(:slot_index, :created_at)
                                        .to_a
      available_generated.each(&:clear_reroll_cooldown_if_elapsed!)
      existing_by_slot = available_generated.index_by(&:slot_index)
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
