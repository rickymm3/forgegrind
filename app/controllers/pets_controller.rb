class PetsController < ApplicationController
  before_action :authenticate_user!

  def index
    @user_pets = current_user.user_pets.includes(:pet, :rarity, :egg)
  end

  def show
    @pet = Pet.find(params[:id])
    @user_pet = current_user.user_pets.find_by(pet: @pet)

    if @user_pet
      @user_pet.catch_up_energy!
    else
      # You might redirect or render a “not found” if the user doesn’t own this pet.
      redirect_to pets_path, alert: "You don’t own that pet."
    end
  end
  
end
