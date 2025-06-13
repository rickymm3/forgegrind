# app/controllers/user_pets_controller.rb

class UserPetsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user_pet, only: [:show, :level_up]

  def index
    @user_pets = current_user.user_pets.includes(:pet, :rarity, :egg)
  end

  def show
    @user_pet.catch_up_energy!
    @pet = @user_pet.pet
  end

  def equip
    @user_pet = current_user.user_pets.find(params[:id])
    slot = params[:slot].to_i

    previous_equipped = nil

    UserPet.transaction do
      current_equipped = current_user.user_pets.equipped.includes(:pet).sort_by { |up| -up.pet.power }

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
    @user_pet = current_user.user_pets.find(params[:id])
    @interaction = params[:interaction_type]

    # 1. Load YAML once for item details
    details = YAML.load_file(Rails.root.join("config/item_details.yml")).with_indifferent_access

    # 2. Determine which item_type is required for this interaction
    requirement_map = {
      "play"      => "frisbee",
      "cuddle"    => "blanket",
      "reprimand" => "whistle",
      "feed"      => "treat",
      "explore"   => "map"
    }
    required_item_type = requirement_map[@interaction]

    # 3. Look up the Item record
    @required_item = Item.find_by(item_type: required_item_type)

    # 4. Check how many the user has
    user_item_record = current_user.user_items.find_by(item: @required_item)
    @user_qty = user_item_record&.quantity.to_i

    # @item_info for display (description, modifiers, etc.)
    @item_info = details[required_item_type] || {}

    respond_to do |format|
      format.turbo_stream
    end
  end

  def unequip
    slot = params[:slot].to_i

    sorted_equipped = current_user.user_pets.equipped.includes(:pet).sort_by { |up| -up.pet.power }
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
    @user_pet = current_user.user_pets.find(params[:id])
  
    # 1) ensure enough EXP
    unless @user_pet.exp >= UserPet::EXP_PER_LEVEL
      redirect_to @user_pet, alert: "Not enough EXP to level up." and return
    end
  
    # 2) fetch & verify held item
    held_item = current_user.user_items.find_by(id: params[:held_user_item_id])
    unless held_item
      redirect_to @user_pet, alert: "You must select an item to hold when leveling up." and return
    end
  
    # 3) perform level up + consume the item
    @user_pet.transaction do
      @user_pet.update!(
        exp:   @user_pet.exp - UserPet::EXP_PER_LEVEL,
        level: @user_pet.level + 1
      )
      held_item.update!(quantity: held_item.quantity - 1)
      @user_pet.update!(held_user_item: held_item)
    end
  
    # 4) auto‐evolve if any rule applies
    rules = PetEvolutionService.applicable_rules(@user_pet)
    if rules.any?
      rule = rules.first
      PetEvolutionService.evolve!(@user_pet, rule)
      notice = "Leveled up to #{@user_pet.level} and evolved into #{rule.child_pet.name}!"
    else
      @user_pet.update!(held_user_item: nil)
      notice = "Leveled up to #{@user_pet.level}!"
    end
  
    redirect_to @user_pet, notice: notice
  end

  # POST /user_pets/:id/interact
  def interact
    user_pet    = current_user.user_pets.find(params[:id])
    interaction = params[:interaction_type]
  
    # 1. Deduct the required item (same as before)
    required_item_type = {
      "play"      => "frisbee",
      "cuddle"    => "blanket",
      "reprimand" => "whistle",
      "feed"      => "treat",
      "explore"   => "map"
    }[interaction]
  
    required_item = Item.find_by(item_type: required_item_type)
    user_item_record = current_user.user_items.find_by(item: required_item)
  
    if user_item_record.nil? || user_item_record.quantity < 1
      flash[:alert] = "You need a #{required_item.name} to #{interaction} with #{user_pet.name}."
      return redirect_to user_pet_path(user_pet)
    end
  
    # 2. Deduct energy & handle sleep (cost = 10)
    energy_cost = 10
    begin
      user_pet.catch_up_energy!
      user_pet.spend_energy!(energy_cost)
    rescue UserPet::PetSleepingError, UserPet::NotEnoughEnergyError => e
      flash[:alert] = e.message
      return redirect_to user_pet_path(user_pet)
    end
  
    # 3. Remove one of the required item
    user_item_record.quantity -= 1
    if user_item_record.quantity.zero?
      user_item_record.destroy!
    else
      user_item_record.save!
    end
  
    # 4. Apply personality changes using apply_interaction (not process_interaction!)
    user_pet.apply_interaction(interaction)
  
    # 5. Save energy, sleep, and personality updates
    user_pet.save!
  
    flash[:notice] = "You #{interaction}ed with #{user_pet.name}!"
    redirect_to user_pet_path(user_pet)
  end

  def preview
    @user_pet = current_user.user_pets.find(params[:id])

    respond_to do |format|
      format.turbo_stream
      format.html { head :not_acceptable }
    end
  end

  # POST /user_pets/:id/energy_tick
  def energy_tick
    @user_pet = current_user.user_pets.find(params[:id])
    @user_pet.catch_up_energy!

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to user_pet_path(@user_pet) }
    end
  end

private

  def set_user_pet
    @user_pet = current_user.user_pets.find(params[:id])
  end
end
