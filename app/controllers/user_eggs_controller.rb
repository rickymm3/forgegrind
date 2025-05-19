class UserEggsController < ApplicationController
  before_action :authenticate_user!

  def create
    egg = Egg.find(params[:egg_id])
  
    unless current_user.can_afford_egg?(egg)
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
        format.html { redirect_to adopt_path, alert: "You don't have the required items." }
      end
      return
    end
  
    UserEgg.transaction do
      current_user.spend_items_for_egg!(egg)
      current_user.user_eggs.create!(egg: egg, hatched: false)
    end
  
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to adopt_path, notice: "You adopted a #{egg.name}!" }
    end
  end
  

  def incubate
    @user_egg = current_user.user_eggs.find(params[:id])
    return if @user_egg.hatched? || @user_egg.hatch_started_at.present?

    @user_egg.update!(hatch_started_at: Time.current)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to pets_path }

    end
  end

  def mark_ready
    @user_egg = current_user.user_eggs.find(params[:id])
  
    unless @user_egg.hatching? && @user_egg.hatch_time_remaining <= 2
      head :unprocessable_entity
      return
    end
  
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to pets_path }

    end
  end

  def hatch
    @user_egg = current_user.user_eggs.find(params[:id])

    UserEgg.transaction do
      @user_egg.update!(hatched: true)
      pet = @user_egg.egg.random_pet
      current_user.user_pets.create!(
        pet:    pet,
        egg:    @user_egg.egg,
        name:   pet.name,
        rarity: pet.rarity,
        power:  pet.power
      )
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "user_egg_hatch_#{@user_egg.id}",
          partial: "nursery/hatched",
          locals: { user_egg: @user_egg }
        )
      end
    end
  end

end
