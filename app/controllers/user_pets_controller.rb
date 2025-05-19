class UserPetsController < ApplicationController
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
      format.turbo_stream {
        render :equip, locals: { previous_pet: previous_equipped }
      }
      format.html { redirect_to pets_path }
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
      format.turbo_stream {
        render :unequip, locals: { target_pet: target_pet }
      }
      format.html { redirect_to pets_path }
    end
  end
  
  

  def preview
    @user_pet = current_user.user_pets.find(params[:id])

    respond_to do |format|
      format.turbo_stream
      format.html { head :not_acceptable }
    end
  end
  
end
