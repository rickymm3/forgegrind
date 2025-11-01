# app/controllers/user_pets_controller.rb

class UserPetsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user_pet, only: [:show, :level_up, :destroy, :interact_preview, :interact, :energy_tick]
  before_action :refresh_pet_state, only: [:show, :interact_preview, :interact, :level_up, :energy_tick]

  def index
    @user_pets = current_user.user_pets.active.includes({ pet: :pet_types }, :rarity)
    @user_eggs = current_user.user_eggs.unhatched.includes(:egg).order(created_at: :asc)
    @active_collection = params[:collection].presence_in(%w[pets eggs]) || "pets"
  end

  def show
    @pet = @user_pet.pet
  end

  def equip
    @user_pet = current_user.user_pets.find(params[:id])
    slot = params[:slot].to_i

    previous_equipped = nil

    UserPet.transaction do
      current_equipped = current_user.user_pets.active.equipped.includes(:pet).sort_by { |up| -up.pet.power }

      if current_equipped[slot]
        previous_equipped = current_equipped[slot]
        previous_equipped.update!(equipped: false)
      end

      @user_pet.update!(equipped: true)
    end

    respond_to do |format|
      format.turbo_stream do
        render :equip, locals: { previous_pet: previous_equipped }
      end
      format.html { redirect_to user_pets_path }
    end
  end

  def interact_preview
    context = panel_context

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
    has_items   = requirements.all? { |req| req[:quantity].to_i >= req[:required_quantity].to_i }
    has_energy  = @user_pet.energy.to_i >= energy_cost

    unless has_energy
      render_action_panel(
        state: :error,
        context: context,
        message: "#{@user_pet.name.presence || @user_pet.pet.name} needs #{energy_cost} energy (#{@user_pet.energy.to_i} available).",
        requirements: requirements
      )
      return
    end

    unless has_items
      render_action_panel(
        state: :error,
        context: context,
        message: "You need additional items for #{interaction.humanize.downcase}.",
        requirements: requirements
      )
      return
    end

    render_action_panel(
      state: :confirm,
      context: context,
      interaction: interaction,
      message: "#{interaction.humanize} will consume #{energy_cost} energy and use the listed items.",
      requirements: requirements,
      energy_cost: energy_cost,
      needs_preview: payload[:needs_preview],
      personality_changes: payload[:personality_changes]
    )
  end

  def unequip
    slot = params[:slot].to_i

    sorted_equipped = current_user.user_pets.active.equipped.includes(:pet).sort_by { |up| -up.pet.power }
    target_pet = sorted_equipped[slot]

    if target_pet
      target_pet.update!(equipped: false)
    end

    respond_to do |format|
      format.turbo_stream do
        render :unequip, locals: { target_pet: target_pet }
      end
      format.html { redirect_to user_pets_path }
    end
  end

  def level_up
    if @user_pet.level >= UserPet::LEVEL_CAP
      redirect_to @user_pet, alert: "#{@user_pet.name} has already reached the max level of #{UserPet::LEVEL_CAP}." and return
    end

    # 1) ensure enough EXP
    unless @user_pet.exp >= UserPet::EXP_PER_LEVEL
      redirect_to @user_pet, alert: "Not enough EXP to level up." and return
    end
  
    # 2) fetch & verify held item
    held_item = current_user.user_items.includes(:item).find_by(id: params[:held_user_item_id])
    unless held_item&.item && UserPet.leveling_stone_types.include?(held_item.item.item_type)
      redirect_to @user_pet, alert: "You must use a leveling stone to level up." and return
    end

    if held_item.quantity.to_i <= 0
      redirect_to @user_pet, alert: "You no longer have any of that stone available." and return
    end
  
    # 3) perform level up + consume the item
    @user_pet.transaction do
      @user_pet.update!(
        exp:   @user_pet.exp - UserPet::EXP_PER_LEVEL,
        level: @user_pet.level + 1
      )
      new_quantity = held_item.quantity.to_i - 1
      if new_quantity <= 0
        held_item.destroy!
      else
        held_item.update!(quantity: new_quantity)
      end
      @user_pet.update!(held_user_item: nil)
    end
  
    # 4) auto‐evolve if any rule applies
    evolution_result = EvolutionEngine.new(user_pet: @user_pet).evaluate_on_level_up!
    notice = if evolution_result.evolved
               apply_evolution!(evolution_result)
             else
               record_evolution_misses(evolution_result.misses)
               "Leveled up to #{@user_pet.level}!"
             end

    redirect_to @user_pet, notice: notice
  end

  def destroy
    pet_name     = @user_pet.name
    glow_essence = @user_pet.glow_essence_reward
    stat         = current_user.user_stat || current_user.create_user_stat!
    turbo_frame_id = request.headers["Turbo-Frame"]
    frame_id       = turbo_frame_id.presence || view_context.dom_id(@user_pet)
    pet_dom_id     = view_context.dom_id(@user_pet)

    total_after_release = nil
    replacement_pet     = nil

    UserPet.transaction do
      stat.with_lock do
        new_total = stat.glow_essence.to_i + glow_essence
        stat.update_columns(
          glow_essence: new_total,
          updated_at:   Time.current
        )
        total_after_release = new_total
      end
      @user_pet.destroy!
      remaining_pets = current_user.user_pets.active.includes(:pet, :rarity, :egg)
      replacement_pet = remaining_pets.first
    end
    replacement_pet&.catch_up_energy!

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
              locals: {
                currencies: helpers.currency_balances_for(current_user)
              }
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

      format.html do
        redirect_to user_pets_path, notice: notice
      end
    end
  end

  # POST /user_pets/:id/interact
  def interact
    context = panel_context
    interaction = params[:interaction_type]
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
      glow_boost: glow_boost
    )

    result = service.run!

    success_message = care_success_message(interaction, result)

    respond_to do |format|
      format.turbo_stream do
        @user_pet.reload
        info_dom    = helpers.dom_id(@user_pet, :info_card)
        action_dom  = helpers.dom_id(@user_pet, :action_panel)
        payload     = interaction_payload(interaction)
        render turbo_stream: [
          turbo_stream.replace(
            info_dom,
            partial: "user_pets/info_body",
            locals: {
              user_pet: @user_pet,
              context: context,
              action_dom_id: action_dom
            }
          ),
          turbo_stream.replace(
            action_dom,
            partial: "user_pets/action_panel",
            locals: {
              user_pet: @user_pet,
              context: context,
              state: payload.present? ? :confirm : :success,
              message: success_message,
              interaction: interaction,
              requirements: payload&.dig(:requirements) || [],
              energy_cost: payload&.dig(:energy_cost),
              needs_preview: payload&.dig(:needs_preview) || [],
              personality_changes: payload&.dig(:personality_changes) || []
            }
          )
        ]
      end
      format.html do
        flash[:notice] = success_message
        redirect_to user_pet_path(@user_pet)
      end
    end
  rescue UserPet::PetSleepingError, UserPet::NotEnoughEnergyError, PetCareService::CareError => e
    respond_to do |format|
      format.turbo_stream do
        render_action_panel(
          state: :error,
          context: context,
          message: e.message
        )
      end
      format.html do
        flash[:alert] = e.message
        redirect_to user_pet_path(@user_pet)
      end
    end
  end

  def preview
    @user_pet = current_user.user_pets.active.find(params[:id])

    respond_to do |format|
      format.turbo_stream
      format.html { head :not_acceptable }
    end
  end

  # POST /user_pets/:id/energy_tick
  def energy_tick
    ticks = @user_pet.catch_up_energy!
    @user_pet.catch_up_needs!(care_ticks: ticks)
    @user_pet.good_day_tick!

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to user_pet_path(@user_pet) }
    end
  end

private

  def set_user_pet
    @user_pet = current_user.user_pets.active.find(params[:id])
    return unless @user_pet.retired?

    if @user_pet.successor_user_pet.present?
      redirect_to user_pet_path(@user_pet.successor_user_pet),
                  notice: "#{@user_pet.name.presence || @user_pet.pet.name} has already evolved into #{@user_pet.successor_user_pet.pet.name}."
    else
      redirect_to user_pets_path,
                  alert: "#{@user_pet.name.presence || @user_pet.pet.name} is no longer available."
    end
    @user_pet = nil
    return
  end

  def refresh_pet_state
    return unless defined?(@user_pet) && @user_pet.present?

    ticks = @user_pet.catch_up_energy!
    @user_pet.catch_up_needs!(care_ticks: ticks)
    @user_pet.good_day_tick!
  end

  def care_success_message(interaction, result)
    needs_delta = result[:needs] || {}
    primary_need = needs_delta.max_by { |_, delta| delta.to_f }&.first
    action_label = interaction.to_s.humanize.downcase

    message = if primary_need.present?
                "You #{action_label} with #{@user_pet.name}! #{primary_need.to_s.humanize} improved."
              else
                "You #{action_label} with #{@user_pet.name}!"
              end

    if result[:glow].present?
      message += " Glow Essence supercharged the effect!"
    end

    message
  end

  def apply_evolution!(result)
    child_pet     = result.child_pet
    rule          = result.rule
    now           = Time.current
    predecessor   = @user_pet
    predecessor_species = predecessor.pet
    successor_pet = nil

    flash[:evolution_reveal] = {
      old_name: predecessor_species.name,
      new_name: child_pet.name,
      old_image_path: helpers.pet_sprite_path(predecessor_species),
      new_image_path: helpers.pet_sprite_path(child_pet)
    }

    successor_pet = PetEvolutionService.evolve!(
      predecessor,
      child_pet: child_pet,
      rule: rule,
      timestamp: now,
      misses: result.misses
    )

    @user_pet = successor_pet
    "#{predecessor_species.name} evolved into #{child_pet.name}! Your new companion is ready to grow."
  end

  def record_evolution_misses(misses)
    misses = Array(misses).compact
    return if misses.blank?

    journal = @user_pet.evolution_journal.deep_dup
    journal["misses"] ||= {}
    misses.each { |key| journal["misses"][key] = true }

    # Derive state flags from specific missed windows to steer future branches
    flags = @user_pet.state_flags.deep_dup
    if misses.include?("L5")
      flags["missed_lvl5_happiness"] = true
    end

    @user_pet.update!(held_user_item: nil, evolution_journal: journal, state_flags: flags)
  end

  def panel_context
    params[:context].presence_in(%w[modal page])&.to_sym || :page
  end

  def build_needs_preview(definition)
    needs = definition[:needs] || {}

    needs.map do |attribute, change|
      attr    = attribute.to_sym
      current = attr == :mood ? @user_pet.mood.to_f : @user_pet.send(attr).to_f
      target  = @user_pet.send(:clamp_need, current + change.to_f)
      delta   = target - current

      before_percent = [[current, 0.0].max, 100.0].min.round(2)
      after_percent  = [[target, 0.0].max, 100.0].min.round(2)

      {
        key: attr,
        label: helpers.need_label(attr),
        before: current.round(1),
        after: target.round(1),
        delta: delta.round(1),
        before_percent: before_percent,
        after_percent: after_percent
      }
    end
  end

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

  def render_action_panel(state:, context:, message: nil, requirements: nil, interaction: nil, energy_cost: nil, needs_preview: [], personality_changes: [])
    requirements ||= []
    action_dom = helpers.dom_id(@user_pet, :action_panel)

    panel_locals = {
      user_pet: @user_pet,
      context: context,
      state: state,
      message: message,
      requirements: requirements,
      interaction: interaction,
      energy_cost: energy_cost,
      needs_preview: needs_preview,
      personality_changes: personality_changes
    }

    respond_to do |format|
      format.turbo_stream do
        if turbo_frame_request?
          render partial: "user_pets/action_panel", formats: :html, locals: panel_locals
        else
          render turbo_stream: turbo_stream.replace(
            action_dom,
            partial: "user_pets/action_panel",
            formats: :html,
            locals: panel_locals
          )
        end
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
      item       = Item.find_by(item_type: item_type)
      user_item  = item ? current_user.user_items.find_by(item: item) : nil
      detail     = care_item_details[item_type] || {}
      {
        item: item,
        type: item_type,
        quantity: user_item&.quantity.to_i,
        required_quantity: 1,
        description: detail[:description] || detail["description"]
      }
    end

    {
      definition: definition,
      energy_cost: energy_cost,
      requirements: requirements,
      needs_preview: build_needs_preview(definition),
      personality_changes: build_personality_preview(definition)
    }
  end

  def care_item_details
    @care_item_details ||= begin
      path = Rails.root.join("config/items.yml")
      path.exist? ? YAML.load_file(path).with_indifferent_access : {}.with_indifferent_access
    end
  end
end
