class NurseryController < ApplicationController
  before_action :authenticate_user!

  def index
    redirect_to user_pets_path(collection: "eggs")
  end

  def hatch
    @user_pet = current_user.user_pets.active.find(params[:id])
    @egg = @user_pet.egg
    @pet = @user_pet.pet
  end
  
end
