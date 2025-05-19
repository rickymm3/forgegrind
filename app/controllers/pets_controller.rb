class PetsController < ApplicationController
  before_action :authenticate_user!

  def index
    @user_pets = current_user.user_pets.includes(:pet, :rarity, :egg)
  end

  def show
    @pet = Pet.includes(:rarity).find(params[:id])
  end
  
end
