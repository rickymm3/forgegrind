class PetsController < ApplicationController
  before_action :authenticate_user!

  def index
    pets = current_user.user_pets.includes(:pet, :rarity, :pet_thought).order(created_at: :asc)
    refresh_pets_state!(pets)

    @view_mode = case params[:view]
                 when "storage" then "storage"
                 when "eggs" then "eggs"
                 else "active"
                 end

    @active_slots = build_active_slots_from(pets)
    @storage_pets = pets.select { |pet| pet.active_slot.nil? }
    @storage_count = @storage_pets.size
    @empty_slots = @active_slots.count(&:nil?)
    @user_eggs = current_user.user_eggs.unhatched.includes(:egg).order(created_at: :asc)
  end

  def show
    @pet = current_user.user_pets.find(params[:id])
    refresh_pet_state(@pet)
    @care_item_counts = helpers.care_item_counts_for(current_user)
    @care_request = @pet.pending_care_request
  end

  def accept_request
    @pet = current_user.user_pets.find(params[:id])
    refresh_pet_state(@pet)
    if @pet.asleep_until.present? && Time.current < @pet.asleep_until
      remaining_minutes = ((@pet.asleep_until - Time.current) / 60).ceil
      flash.now[:alert] = "#{@pet.name} is asleep for another #{remaining_minutes} minute#{'s' if remaining_minutes != 1}."
      render_request_stream and return
    end
    service = PetRequestService.new(@pet)

    begin
      result = service.accept!(
        use_items: params[:use_items] != "false",
        care_item: params[:care_item]
      )
      notice = "Request accepted"
      notice += " · Action performed" if result.present?
      flash.now[:notice] = notice
      @pet.reload
    rescue StandardError => e
      flash.now[:alert] = e.message
    end

    render_request_stream
  end

  def decline_request
    @pet = current_user.user_pets.find(params[:id])
    refresh_pet_state(@pet)
    PetRequestService.new(@pet).decline!
    @pet.reload
    flash.now[:notice] = "Request snoozed"

    render_request_stream
  end

  def collect_passive
    @pet = current_user.user_pets.find(params[:id])
    unless @pet.active_slot.present?
      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = "Only active pets generate coins."
          render turbo_stream: turbo_stream.update(
            "flash_messages",
            partial: "shared/flash_messages",
            locals: { flash_messages: flash }
          )
        end
        format.html { redirect_to pets_path, alert: "Only active pets generate coins." }
      end
      return
    end
    refresh_pet_state(@pet)
    granted = @pet.collect_held_coins!(now: Time.current)

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = "Collected #{granted} Coins" if granted.positive?
        render turbo_stream: [
          turbo_stream.replace(
            helpers.pet_slot_dom_id(@pet, @pet.active_slot || 0),
            partial: "pets/active_slot",
            locals: { pet: @pet, index: @pet.active_slot || 0 }
          ),
          turbo_stream.update(
            "flash_messages",
            partial: "shared/flash_messages",
            locals: { flash_messages: flash }
          )
        ]
      end
      format.html { redirect_to pets_path, notice: granted.positive? ? "Collected #{granted} Coins" : "No coins ready to collect yet." }
    end
  end

  def select
    @slot_index = slot_param
    @active_slots = current_user.active_pet_slots
    @current_pet = @active_slots[@slot_index]
    selection_param = params[:selected_pet_id]
    @empty_selection = selection_param == "none"

    @selected_pet = if selection_param.present? && !@empty_selection
                      current_user.user_pets.find_by(id: selection_param)
                    else
                      @current_pet
                    end
    @preview_pet = @empty_selection ? nil : @selected_pet
    @selection_ready = @empty_selection || @preview_pet.present?

    @storage_pets = current_user.user_pets.where(active_slot: nil).includes(:pet, :rarity).order(created_at: :asc)

    if turbo_frame_request?
      render :select
    else
      redirect_to pets_path
    end
  end

  def assign
    slot = slot_param
    clear_slot = ActiveModel::Type::Boolean.new.cast(params[:clear_slot])
    current_pet = current_user.active_pet_slots[slot]
    selected_pet = if clear_slot
                     nil
                   elsif params[:user_pet_id].present?
                     current_user.user_pets.find_by(id: params[:user_pet_id])
                   else
                     current_pet
                   end

    current_user.assign_pet_to_slot!(slot, selected_pet)
    @active_slots = current_user.active_pet_slots
    storage_count = current_user.user_pets.where(active_slot: nil).count
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update(
            "pet-hub-main",
            partial: "pets/active_slots",
            locals: { active_slots: @active_slots }
          ),
          turbo_stream.replace(
            "pet-hub-meta",
            partial: "pets/header_meta",
            locals: { active_slots: @active_slots, storage_count: storage_count }
          )
        ]
      end
      format.html { redirect_to pets_path, notice: "Pet slots updated." }
    end
  rescue ActiveRecord::RecordNotFound, ArgumentError
    storage_count = current_user.user_pets.where(active_slot: nil).count
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update(
            "pet-hub-main",
            partial: "pets/active_slots",
            locals: { active_slots: current_user.active_pet_slots }
          ),
          turbo_stream.replace(
            "pet-hub-meta",
            partial: "pets/header_meta",
            locals: { active_slots: current_user.active_pet_slots, storage_count: storage_count }
          )
        ]
      end
      format.html { redirect_to pets_path, alert: "Unable to update slot." }
    end
  end

  private

  def build_active_slots_from(pets)
    slots = Array.new(User::ACTIVE_PET_SLOT_COUNT)
    pets.each do |pet|
      next if pet.active_slot.nil?
      slots[pet.active_slot] = pet
    end
    slots
  end

  def refresh_pets_state!(pets)
    Array(pets).each { |pet| refresh_pet_state(pet) }
  end

  def refresh_pet_state(pet)
    return unless pet

    ticks = pet.catch_up_energy!
    pet.catch_up_needs!(care_ticks: ticks)
    pet.accrue_held_coins!
    pet.ensure_sleep_state!
    PetThoughtRefresher.refresh!(pet)
    PetRequestService.new(pet).refresh_request!
  end

  def render_request_stream
    @care_request = @pet.pending_care_request
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "pet-care-request",
          partial: "pets/care_alerts",
          locals: {
            pet: @pet,
            care_request: @care_request,
            request_cooldown_until: @pet.care_request_cooldown_until
          }
        )
      end
      format.html { redirect_to pet_path(@pet) }
    end
  end

  def slot_param
    slot = params[:slot].to_i
    raise ArgumentError unless slot.between?(0, User::ACTIVE_PET_SLOT_COUNT - 1)

    slot
  end
end
