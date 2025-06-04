class NurseryController < ApplicationController
  before_action :authenticate_user!

  def index
    @user_eggs = current_user.user_eggs.includes(:egg)
  end

  def hatch
    @user_pet = current_user.user_pets.find(params[:id])
    @egg = @user_pet.egg
    @pet = @user_pet.pet
  end
  
end
