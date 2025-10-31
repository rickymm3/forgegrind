class UserEggsController < ApplicationController
  before_action :authenticate_user!

  def create
    egg = Egg.find(params[:egg_id])
    @egg = egg
  
    unless current_user.can_afford_egg?(egg)
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
        format.html { redirect_to adopt_path, alert: "You don't have the required items." }
      end
      return
    end
  
    UserEgg.transaction do
      current_user.spend_currency_for_egg!(egg)
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
      format.html { redirect_to user_pets_path }
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
      format.html { redirect_to user_pets_path }

    end
  end

# app/controllers/user_eggs_controller.rb

def hatch
  @user_egg = current_user.user_eggs.find(params[:id])
  pet = nil

  UserEgg.transaction do
    @user_egg.update!(hatched: true)
    pet = @user_egg.egg.random_pet

    random_thought = PetThought.order("RANDOM()").first

    @user_pet = current_user.user_pets.create!(
      pet:           pet,
      egg:           @user_egg.egg,
      name:          pet.name,
      rarity:        pet.rarity,
      power:         pet.power,
      playfulness:   rand(1..10),
      affection:     rand(1..10),
      temperament:   rand(1..10),
      curiosity:     rand(1..10),
      confidence:    rand(1..10),
      pet_thought:   random_thought
    )
  end

  redirect_to nursery_hatch_path(@user_pet.id)
end

  # def hatch
  #   @user_egg = current_user.user_eggs.find(params[:id])
  #   @egg_frame_id = "user_egg_hatch_#{@user_egg.id}" # Define the frame ID for the main page

  #   UserEgg.transaction do
  #     @user_egg.update!(hatched: true)
  #     pet = @user_egg.egg.random_pet # Assuming egg.random_pet is defined
  #     @user_pet = current_user.user_pets.create!(
  #       pet:    pet,
  #       egg:    @user_egg.egg,
  #       name:   pet.name,
  #       rarity: pet.rarity,
  #       power:  pet.power
  #     )
  #   end

  #   # Respond with turbo_stream directly
  #   respond_to do |format|
  #     format.html { redirect_to nursery_path } # Fallback for non-turbo requests
  #     format.turbo_stream do
  #       # This will implicitly render user_eggs/hatch.turbo_stream.haml
  #       # or you can explicitly render:
  #       # render turbo_stream: [
  #       #   turbo_stream.update(@egg_frame_id, partial: "nursery/hatched", locals: { user_egg: @user_egg }),
  #       #   turbo_stream.update("hatch-modal-content-frame", partial: "nursery/hatch_modal_content", locals: { pet: @user_pet.pet, egg: @user_egg.egg })
  #       # ]
  #     end
  #   end
  # rescue ActiveRecord::RecordNotFound
  #   redirect_to nursery_path, alert: "Egg not found."
  # rescue StandardError => e
  #   Rails.logger.error "Hatching error: #{e.message}"
  #   respond_to do |format|
  #     format.html { redirect_to nursery_path, alert: "Error hatching egg." }
  #     format.turbo_stream { head :unprocessable_entity } # Or render an error stream
  #   end
  # end

end
