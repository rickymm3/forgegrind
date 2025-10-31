# app/controllers/user_pets_controller.rb

class UserPetsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user_pet, only: [:show, :level_up, :destroy, :interact_preview, :interact, :energy_tick]
  before_action :refresh_pet_state, only: [:show, :interact_preview, :interact, :level_up, :energy_tick]

  def index
    @user_pets = current_user.user_pets.active.includes({ pet: :pet_types }, :rarity)
    @selected_pet = @user_pets.first
    @pet_types = PetType.order(:name)
  end

  def show
    @pet = @user_pet.pet

    if turbo_frame_request?
      render partial: "user_pets/detail_frame", locals: { user_pet: @user_pet }
      return
    end
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
    @interaction = params[:interaction_type]
    definition = PetCareService::ACTIONS[@interaction]
    unless definition
      head :unprocessable_entity and return
    end

    if @user_pet.exploring?
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(
            "interaction-action",
            partial: "user_pets/interaction_locked",
            locals: { user_pet: @user_pet }
          )
        end
        format.html do
          redirect_to user_pet_path(@user_pet), alert: "#{@user_pet.name} is currently exploring."
        end
      end
      return
    end

    details = YAML.load_file(Rails.root.join("config/item_details.yml")).with_indifferent_access

    energy_cost       = definition[:energy_cost].to_i
    needs_delta       = definition[:needs] || {}
    personality_delta = definition[:personality] || {}

    requirements = Array(definition[:required_item_types]).map do |item_type|
      item = Item.find_by(item_type: item_type)
      user_item = item ? current_user.user_items.find_by(item: item) : nil
      detail_entry = details[item_type] || {}
      description = detail_entry[:description] || detail_entry["description"]
      {
        item: item,
        type: item_type,
        quantity: user_item&.quantity.to_i,
        required_quantity: 1,
        description: description
      }
    end

    has_items = requirements.all? { |req| req[:quantity].to_i >= req[:required_quantity].to_i }
    has_energy = @user_pet.energy.to_i >= energy_cost
    can_perform = has_items && has_energy

    glow_balance = current_user.user_stat&.glow_essence.to_i
    glow_multiplier = PetCareService::GLOW_ESSENCE_BOOST

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "interaction-action",
          partial: "user_pets/interact_preview",
          locals: {
            user_pet: @user_pet,
            interaction: @interaction,
            requirements: requirements,
            energy_cost: energy_cost,
            needs_delta: needs_delta,
            personality_delta: personality_delta,
            can_perform: can_perform,
            glow_essence_balance: glow_balance,
            glow_multiplier: glow_multiplier
          }
        )
      end
    end
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
    interaction = params[:interaction_type]
    if @user_pet.exploring?
      flash[:alert] = "#{@user_pet.name} is currently exploring and can’t interact right now."
      redirect_to user_pet_path(@user_pet) and return
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

    flash[:notice] = care_success_message(interaction, result)
    redirect_to user_pet_path(@user_pet)
  rescue UserPet::PetSleepingError, UserPet::NotEnoughEnergyError, PetCareService::CareError => e
    flash[:alert] = e.message
    redirect_to user_pet_path(@user_pet)
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

end
