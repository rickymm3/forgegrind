# app/controllers/user_pets_controller.rb

class UserPetsController < ApplicationController
  before_action :authenticate_user!

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
      format.html { redirect_to pets_path }
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
      format.html { redirect_to pets_path }
    end
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
      return redirect_to pet_path(user_pet.pet)
    end
  
    # 2. Deduct energy & handle sleep (cost = 10)
    energy_cost = 10
    begin
      user_pet.catch_up_energy!
      user_pet.spend_energy!(energy_cost)
    rescue UserPet::PetSleepingError, UserPet::NotEnoughEnergyError => e
      flash[:alert] = e.message
      return redirect_to pet_path(user_pet.pet)
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
    redirect_to pet_path(user_pet.pet)
  end

  # POST /user_pets/:id/level_up
  def level_up
    user_pet = current_user.user_pets.find(params[:id])

    unless user_pet.can_level_up?
      flash[:alert] = if user_pet.level >= UserPet::LEVEL_CAP
                        "#{user_pet.name} is already at max level."
                      else
                        "Not enough EXP to level up."
                      end
      redirect_to pet_path(user_pet.pet) and return
    end

    user_pet.level_up!
    flash[:notice] = "#{user_pet.name} reached level #{user_pet.level}!"
    redirect_to pet_path(user_pet.pet)
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
      format.html { redirect_to pet_path(@user_pet.pet) }
    end
  end
end
