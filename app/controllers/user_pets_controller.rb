class UserPetsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user_pet, only: [:show, :level_up, :destroy, :interact_preview, :interact, :energy_tick, :details_panel, :overview_panel, :level_up_panel]
  before_action :guard_retired_pet!, only: [:show, :level_up, :interact_preview, :interact, :energy_tick, :details_panel, :overview_panel, :level_up_panel]
  before_action :refresh_pet_state, only: [:show, :interact_preview, :interact, :level_up, :energy_tick, :details_panel, :overview_panel, :level_up_panel]

  def index
    @user_pets = current_user.user_pets.active.includes({ pet: :pet_types }, :rarity, :pet_thought)
    @user_eggs = current_user.user_eggs.unhatched.includes(:egg).order(created_at: :asc)
    @active_collection = params[:collection].presence_in(%w[pets eggs]) || "pets"

    PetThoughtRefresher.refresh!(@user_pets)
  end

  def show
    @pet = @user_pet.pet
  end

  def details_panel
    render_panel(:details, extra_locals: { leveling_items: available_leveling_items })
  end

  def overview_panel
    render_panel(:overview)
  end

  def level_up_panel
    if @user_pet.level >= UserPet::LEVEL_CAP
      flash[:alert] = "Max level reached."
      return redirect_to user_pet_path(@user_pet)
    end

    unless @user_pet.exp >= UserPet::EXP_PER_LEVEL
      flash[:alert] = "Earn #{UserPet::EXP_PER_LEVEL - @user_pet.exp.to_i} more XP to level up."
      return redirect_to user_pet_path(@user_pet)
    end

    render_panel(:level_up, extra_locals: { leveling_items: available_leveling_items })
  end

  def equip
    @user_pet = current_user.user_pets.find(params[:id])
    slot = params[:slot].to_i
    unless slot.between?(0, User::ACTIVE_PET_SLOT_COUNT - 1)
      head :unprocessable_entity and return
    end

    previous_equipped = current_user.user_pets.find_by(active_slot: slot)
    current_user.assign_pet_to_slot!(slot, @user_pet)

    respond_to do |format|
      format.turbo_stream { render :equip, locals: { previous_pet: previous_equipped } }
      format.html { redirect_to user_pets_path }
    end
  end

  def interact_preview
    context = params[:context].presence&.to_sym || :page
    use_item = ActiveModel::Type::Boolean.new.cast(params[:use_item])

    if params[:cancel].present?
      render_action_panel(state: :idle, context: context) and return
    end

    interaction = params[:interaction_type].to_s
    payload = interaction_payload(interaction)
    definition = payload&.dig(:definition)
    unless definition
      render_action_panel(
        state: :error,
        context: context,
        message: "That action is not available."
      )
      return
    end

    if @user_pet.exploring?
      render_action_panel(
        state: :error,
        context: context,
        message: "#{@user_pet.name.presence || @user_pet.pet.name} is currently exploring."
      )
      return
    end

    if @user_pet.asleep_until.present? && Time.current < @user_pet.asleep_until
      minutes_left = ((@user_pet.asleep_until - Time.current) / 60).ceil
      render_action_panel(
        state: :error,
        context: context,
        message: "#{@user_pet.name.presence || @user_pet.pet.name} is resting for another #{helpers.pluralize(minutes_left, 'minute')}."
      )
      return
    end

    requirements = payload[:requirements]
    energy_cost  = payload[:energy_cost]
    has_energy   = @user_pet.energy.to_i >= energy_cost

    unless has_energy
      render_action_panel(
        state: :error,
        context: context,
        message: "#{@user_pet.name.presence || @user_pet.pet.name} needs #{energy_cost} energy (#{@user_pet.energy.to_i} available).",
        requirements: requirements
      )
      return
    end

    care_item_options = CareItemResolver.new(current_user).available_for(interaction)

    render_action_panel(
      state: :confirm,
      context: context,
      interaction: interaction,
      message: "#{interaction.humanize} will consume #{energy_cost} energy. Items boost the effect if used.",
      requirements: requirements,
      energy_cost: energy_cost,
      needs_preview: payload[:needs_preview],
      personality_changes: payload[:personality_changes],
      tracker_snapshot: payload[:tracker_snapshot],
      use_item: use_item,
      care_item_options: care_item_options
    )
  end

  def unequip
    slot = params[:slot].to_i
    unless slot.between?(0, User::ACTIVE_PET_SLOT_COUNT - 1)
      head :unprocessable_entity and return
    end
    target_pet = current_user.user_pets.find_by(active_slot: slot)
    current_user.clear_pet_slot!(slot)

    respond_to do |format|
      format.turbo_stream { render :unequip, locals: { target_pet: target_pet } }
      format.html { redirect_to user_pets_path }
    end
  end

  def level_up
    if @user_pet.level >= UserPet::LEVEL_CAP
      redirect_to @user_pet, alert: "#{@user_pet.name} has already reached the max level of #{UserPet::LEVEL_CAP}." and return
    end

    unless @user_pet.exp >= UserPet::EXP_PER_LEVEL
      redirect_to @user_pet, alert: "Not enough EXP to level up." and return
    end

    held_item = current_user.user_items.includes(:item).find_by(id: params[:held_user_item_id])
    if held_item.present?
      valid_item = held_item.item && UserPet.leveling_stone_types.include?(held_item.item.item_type)
      unless valid_item && held_item.quantity.to_i.positive?
        redirect_to @user_pet, alert: "The selected item can’t be used to enhance this level up." and return
      end
    end

    evolution_result = nil

    @user_pet.transaction do
      @user_pet.update!(held_user_item: held_item) if held_item.present?

      @user_pet.update!(
        exp:   @user_pet.exp - UserPet::EXP_PER_LEVEL,
        level: @user_pet.level + 1
      )

      evolution_result = EvolutionEngine.new(user_pet: @user_pet).evaluate_on_level_up!

      if held_item.present?
        @user_pet.update!(held_user_item: nil)

        new_quantity = held_item.quantity.to_i - 1
        if new_quantity <= 0
          held_item.destroy!
        else
          held_item.update!(quantity: new_quantity)
        end
      end
    end

    notice = if evolution_result.evolved
               apply_evolution!(evolution_result)
             else
               record_evolution_misses(evolution_result.misses)
               "Leveled up to #{@user_pet.level}!"
             end

    current_user.grant_player_experience!(GameConfig.player_exp_for_pet_level_up)

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = notice
        render_panel_stream(panel_partial_for(:overview), panel_locals)
      end
      format.html { redirect_to @user_pet, notice: notice }
    end
  end

  def destroy
    pet_name         = @user_pet.name
    glow_essence     = @user_pet.glow_essence_reward
    glow_currency    = Currency.find_by_key(:glow_essence)
    glow_wallet      = glow_currency ? current_user.currency_wallet_for(glow_currency) : nil
    turbo_frame_id   = request.headers["Turbo-Frame"]
    frame_id         = turbo_frame_id.presence || view_context.dom_id(@user_pet)
    pet_dom_id       = view_context.dom_id(@user_pet)

    total_after_release = nil
    replacement_pet     = nil

    UserPet.transaction do
      if glow_wallet
        glow_wallet.credit!(glow_essence)
        total_after_release = glow_wallet.balance
      end
      @user_pet.destroy!
      remaining_pets = current_user.user_pets.active.includes(:pet, :rarity, :egg)
      replacement_pet = remaining_pets.first
    end
    replacement_pet&.catch_up_energy!

    total_after_release ||= glow_wallet&.balance.to_i || 0
    notice = "#{pet_name} was released. You gained #{glow_essence} Glow Essence (#{total_after_release} total)."

    respond_to do |format|
      format.turbo_stream do
        if turbo_frame_id.present? && turbo_frame_id != "_top"
          flash.now[:notice] = notice
          render turbo_stream: [
            turbo_stream.remove(frame_id),
            turbo_stream.remove(pet_dom_id),
            turbo_stream.replace(
              "pet_detail",
              partial: "user_pets/detail_frame",
              locals: { user_pet: replacement_pet }
            ),
            turbo_stream.replace(
              "currency_balances",
              partial: "shared/currency_badges",
              locals: { currencies: helpers.currency_balances_for(current_user) }
            ),
            turbo_stream.replace(
              "flash_messages",
              partial: "shared/flash_messages",
              locals: { flash_messages: flash }
            )
          ]
        else
          flash[:notice] = notice
          redirect_to user_pets_path, status: :see_other
        end
      end
      format.html { redirect_to user_pets_path, notice: notice }
    end
  end

  # POST /user_pets/:id/interact
  def interact
    context = params[:context].presence&.to_sym || :page
    interaction = params[:interaction_type]
    use_item = params.key?(:use_item) ? ActiveModel::Type::Boolean.new.cast(params[:use_item]) : true
    alert_metric = params[:alert_metric].presence

    if @user_pet.exploring?
      render_action_panel(
        state: :error,
        context: context,
        message: "#{@user_pet.name.presence || @user_pet.pet.name} is currently exploring."
      )
      return
    end

    glow_boost = ActiveModel::Type::Boolean.new.cast(params[:use_glow_essence])

    service = PetCareService.new(
      user_pet: @user_pet,
      user: current_user,
      interaction_type: interaction,
      item_ids: params[:item_ids],
      glow_boost: glow_boost,
      use_items: use_item,
      care_item: params[:care_item]
    )

    result = service.run!
    success_message = care_success_message(interaction, result)
    helpers.record_care_alert_snooze!(alert_metric) if alert_metric.present?
    current_user.user_items.reload
    flash.now[:notice] = success_message
    PetRequestService.new(@user_pet).complete_request!(status: "accepted")

    respond_to do |format|
      format.turbo_stream do
        @user_pet.reload
        info_dom     = helpers.info_panel_dom_id(@user_pet)
        action_dom   = helpers.action_panel_dom_id(@user_pet)
        payload      = interaction_payload(interaction)
        requirements = payload&.dig(:requirements) || []

        panel_state = payload.present? ? :success : :success
        panel_message = success_message

        energy_cost         = payload&.dig(:energy_cost)
        needs_preview       = payload&.dig(:needs_preview) || []
        personality_changes = payload&.dig(:personality_changes) || []

        needs_snapshot = serialized_need_snapshot(@user_pet)

        stats_dom   = helpers.pet_stats_dom_id(@user_pet)
        alerts_dom  = helpers.care_alert_dom_id(@user_pet)
        alerts_list = helpers.care_alerts_for(
          @user_pet,
          item_counts: helpers.care_item_counts_for(current_user)
        )

        streams = [
          turbo_stream.update(
            info_dom,
            partial: "user_pets/info_body",
            locals: { user_pet: @user_pet, context: context, action_dom_id: action_dom }
          ),
          turbo_stream.update(
            stats_dom,
            partial: "user_pets/stats_grid",
            locals: { user_pet: @user_pet }
          ),
          turbo_stream.replace(
            action_dom,
            partial: "user_pets/action_panel_frame",
            formats: :html,
            locals: {
              user_pet: @user_pet,
              context: context,
              state: panel_state,
              message: panel_message,
              interaction: interaction,
              requirements: requirements,
              energy_cost: energy_cost,
              needs_preview: needs_preview,
              personality_changes: personality_changes,
              tracker_snapshot: tracker_snapshot,
              needs_snapshot: needs_snapshot,
              use_item: use_item
            }
          )
        ]

        if context == :detail_alert
          streams << turbo_stream.replace(
            alerts_dom,
            partial: "pets/care_alerts",
            locals: { pet: @user_pet, care_alerts: alerts_list }
          )
        end

        if flash.any?
          streams << turbo_stream.update(
            "flash_messages",
            partial: "shared/flash_messages",
            locals: { flash_messages: flash }
          )
        end

        render turbo_stream: streams
      end

      format.html do
        flash[:notice] = success_message
        redirect_to user_pet_path(@user_pet)
      end
    end
  rescue UserPet::PetSleepingError, UserPet::NotEnoughEnergyError, PetCareService::CareError => e
    respond_to do |format|
      format.turbo_stream do
        payload = interaction_payload(interaction)
        render_action_panel(
          state: :error,
          context: context,
          message: e.message,
          requirements: payload&.dig(:requirements),
          interaction: interaction,
          energy_cost: payload&.dig(:energy_cost),
          needs_preview: payload&.dig(:needs_preview) || [],
          personality_changes: payload&.dig(:personality_changes) || [],
          tracker_snapshot: payload&.dig(:tracker_snapshot),
          care_item_options: CareItemResolver.new(current_user).available_for(interaction)
        )
      end
      format.html { redirect_to user_pet_path(@user_pet), alert: e.message }
    end
  end

  # NOTE: Removed a broken `preview` action that contained stray code and unbalanced `end`s.
  # If you need a preview endpoint, reintroduce it with a proper implementation and tests.

  def build_personality_preview(definition)
    personalities = definition[:personality] || {}
    personalities.map do |attribute, change|
      {
        key: attribute.to_sym,
        label: attribute.to_s.humanize,
        delta: change.to_f.round(1)
      }
    end
  end

  def build_needs_preview(definition)
    adjustments = Array(definition[:needs])
    return [] if adjustments.blank?

    simulator_pet = @user_pet.dup
    simulator_pet.state_flags = @user_pet.state_flags.deep_dup if simulator_pet.respond_to?(:state_flags) && @user_pet.state_flags.present?

    before_values = {}
    after_values  = {}
    mood_delta    = 0.0

    adjustments.each do |key, delta|
      attr  = key.to_sym
      value = delta.to_f
      if attr == :mood
        before_values[:mood] ||= @user_pet.mood.to_f
        mood_delta += value
        next
      end

      next unless simulator_pet.respond_to?(attr)

      current = @user_pet.send(attr).to_f
      updated = simulator_pet.send(:clamp_need, current + value)
      simulator_pet.send("#{attr}=", updated)
      before_values[attr] = current
      after_values[attr]  = updated
    end

    personality_adjustments = Array(definition[:personality])
    personality_adjustments.each do |key, delta|
      attr = key.to_sym
      next unless simulator_pet.respond_to?(attr)
      simulator_pet.send("#{attr}=", simulator_pet.send(attr).to_f + delta.to_f)
    end

    simulator_pet.recalc_mood!(save: false)
    if before_values.key?(:mood) || mood_delta.nonzero?
      before_values[:mood] ||= @user_pet.mood.to_f
      recalculated = simulator_pet.mood.to_f
      adjusted     = simulator_pet.send(:clamp_need, recalculated + mood_delta)
      after_values[:mood] = adjusted
    end

    adjustments.map do |key, _|
      attr = key.to_sym
      before = if before_values.key?(attr)
                 before_values[attr]
               elsif @user_pet.respond_to?(attr)
                 @user_pet.send(attr).to_f
               end
      after = if after_values.key?(attr)
                after_values[attr]
              elsif simulator_pet.respond_to?(attr)
                simulator_pet.send(attr).to_f
              end
      next unless before && after

      {
        key: attr,
        before: before,
        after: after,
        delta: after - before,
        before_percent: before.clamp(0.0, 100.0),
        after_percent: after.clamp(0.0, 100.0)
      }
    end.compact
  end

  def render_action_panel(state:, context:, message: nil, requirements: nil, interaction: nil, energy_cost: nil, needs_preview: [], personality_changes: [], tracker_snapshot: nil, use_item: nil, care_item_options: [])
    requirements ||= []
    action_dom = helpers.action_panel_dom_id(@user_pet)
    energy_cost = energy_cost.to_i if energy_cost

    energy_before = @user_pet.energy.to_f
    energy_after = (energy_before - energy_cost.to_i).clamp(0.0, UserPet::MAX_ENERGY.to_f)
    xp_before = @user_pet.exp.to_i
    xp_gain = (state == :confirm && interaction.present?) ? PetCareService::CARE_EXP_REWARD : 0
    xp_after = (xp_before + xp_gain).clamp(0, UserPet::EXP_PER_LEVEL)

    panel_locals = {
      user_pet: @user_pet,
      context: context,
      state: state,
      message: message,
      requirements: requirements,
      interaction: interaction,
      energy_cost: energy_cost,
      needs_preview: needs_preview,
      personality_changes: personality_changes,
      preview_energy_before: energy_before,
      preview_energy_after: energy_after,
      preview_xp_before: xp_before,
      preview_xp_after: xp_after,
      preview_xp_gain: xp_gain,
      tracker_snapshot: tracker_snapshot,
      use_item: use_item,
      care_item_options: care_item_options
    }

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          action_dom,
          partial: "user_pets/action_panel_frame",
          formats: :html,
          locals: panel_locals
        )
      end
      format.html do
        flash[:alert] = message if message.present? && state == :error
        redirect_to user_pet_path(@user_pet)
      end
    end
  end

  def interaction_payload(interaction)
    definition = PetCareService::ACTIONS[interaction]
    return nil unless definition

    energy_cost = definition[:energy_cost].to_i
    requirements = Array(definition[:required_item_types]).map do |item_type|
      item      = Item.find_by(item_type: item_type)
      user_item = item ? current_user.user_items.find_by(item: item) : nil
      detail    = care_item_details[item_type] || {}
      {
        item: item,
        type: item_type,
        quantity: user_item&.quantity.to_i,
        required_quantity: 1,
        optional: true,
        description: detail[:description] || detail["description"]
      }
    end

    {
      definition: definition,
      energy_cost: energy_cost,
      requirements: requirements,
      needs_preview: build_needs_preview(definition),
      personality_changes: build_personality_preview(definition),
      tracker_snapshot: tracker_snapshot
    }
  end

  def care_item_details
    @care_item_details ||= begin
      path = Rails.root.join("config/items.yml")
      path.exist? ? YAML.load_file(path).with_indifferent_access : {}.with_indifferent_access
    end
  end

  def tracker_snapshot
    {
      hunger_score: @user_pet.care_tracker_value(:hunger_score),
      hygiene_score: @user_pet.care_tracker_value(:hygiene_score),
      boredom_score: @user_pet.care_tracker_value(:boredom_score),
      injury_score: @user_pet.care_tracker_value(:injury_score),
      mood_score: @user_pet.care_tracker_value(:mood_score)
    }
  end

  def serialized_need_snapshot(pet)
    %i[hunger hygiene boredom injury_level mood].map do |metric|
      next unless pet.respond_to?(metric)
      value = pet.send(metric).to_f
      {
        key: metric,
        value: value,
        percent: value.clamp(UserPet::NEEDS_MIN, UserPet::NEEDS_MAX)
      }
    end.compact
  end

  private

  # Expect these helpers to exist elsewhere in your codebase.
  def set_user_pet
    @user_pet = current_user.user_pets.includes(:pet, :rarity, :pet_thought).find(params[:id])
  end

  def refresh_pet_state
    return unless @user_pet

    ticks = @user_pet.catch_up_energy!
    @user_pet.catch_up_needs!(care_ticks: ticks)
    @user_pet.accrue_held_coins!
    @user_pet.ensure_sleep_state!
    PetThoughtRefresher.refresh!(@user_pet)
    PetRequestService.new(@user_pet).refresh_request!
  end

  def panel_context
    { return_to: request.referer }
  end

  def care_success_message(interaction, result)
    base = "#{interaction.to_s.humanize} successful"
    if result.is_a?(Hash) && result.dig(:critical, :triggered)
      "#{base} · Critical Care bonus!"
    elsif result.respond_to?(:delta) && result.delta
      "#{base} (+#{result.delta})"
    else
      base
    end
  end

  def render_panel(type, extra_locals: {})
    partial = panel_partial_for(type)
    locals = panel_locals(extra_locals)
    frame_id = helpers.user_pet_panel_dom_id(@user_pet)

    respond_to do |format|
      format.turbo_stream { render_panel_stream(partial, locals, frame_id) }
      format.html do
        if turbo_frame_request?
          html_content = render_to_string(partial: partial, locals: locals, formats: [:html])
          frame_html = view_context.tag.turbo_frame(id: frame_id) { html_content }
          render html: frame_html
        else
          redirect_to user_pet_path(@user_pet)
        end
      end
    end
  end

  def apply_evolution!(result)
    successor = PetEvolutionService.evolve!(
      @user_pet,
      rule: result.rule,
      child_pet: result.child_pet,
      timestamp: Time.current,
      misses: result.misses
    )

    @user_pet = successor
    @pet = successor.pet

    "#{successor.name} evolved!"
  rescue StandardError => e
    Rails.logger.error("[UserPetsController] evolution failed: #{e.class} - #{e.message}")
    "Leveled up to #{@user_pet.level}!"
  end

  def record_evolution_misses(misses)
    return if misses.blank?

    journal = @user_pet.evolution_journal.deep_dup
    journal["misses"] ||= {}

    Array(misses).each do |miss_key|
      next if miss_key.blank?
      key = miss_key.to_s
      journal["misses"][key] = journal["misses"].fetch(key, 0) + 1
    end

    @user_pet.update!(evolution_journal: journal)
  rescue StandardError => e
    Rails.logger.warn("[UserPetsController] record_evolution_misses failed: #{e.class} - #{e.message}")
  end

  def available_leveling_items
    @available_leveling_items ||= current_user.user_items
                                              .includes(:item)
                                              .joins(:item)
                                              .where(items: { item_type: UserPet.leveling_stone_types })
                                              .where("user_items.quantity > 0")
  end

  def guard_retired_pet!
    return unless @user_pet&.retired?

    successor = @user_pet.successor_user_pet
    notice = if successor
               "#{@user_pet.name.presence || @user_pet.pet.name} has evolved into #{successor.name.presence || successor.pet.name}."
             else
               "#{@user_pet.name.presence || @user_pet.pet.name} has retired and can no longer be interacted with."
             end

    redirect_target = successor ? user_pet_path(successor) : user_pets_path
    redirect_to redirect_target, alert: notice
  end

  def panel_partial_for(type)
    case type
    when :details then "user_pets/panel_details"
    when :level_up then "user_pets/level_up_panel"
    else
      "user_pets/panel_overview"
    end
  end

  def panel_locals(extra = {})
    { user_pet: @user_pet }.merge(extra)
  end

  def render_panel_stream(partial, locals, frame_id = helpers.user_pet_panel_dom_id(@user_pet))
    render turbo_stream: turbo_stream.replace(frame_id, partial: partial, locals: locals)
  end
end
