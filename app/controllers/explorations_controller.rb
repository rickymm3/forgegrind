class ExplorationsController < ApplicationController
  def index
    @worlds = World.all
    @user_explorations = current_user.user_explorations.includes(:world).where(completed_at: nil)
  end

  def start
    @world = World.find(params[:id])
  
    # Check if user already has an active exploration for this world
    existing = current_user.user_explorations.find_by(world: @world, completed_at: nil)
  
    if existing.present?
      # Optionally: flash message or noop response
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.update("exploration_#{@world.id}", partial: "explorations/countdown", locals: { user_exploration: existing }) }
      end
      return
    end
  
    user_pet_ids = Array(params[:user_pet_ids]).first(3)

    @user_exploration = current_user.user_explorations.create!(world: @world, started_at: Time.current)
    if user_pet_ids.any?
      @user_exploration.user_pets << current_user.user_pets.where(id: user_pet_ids)
    end
  
    respond_to do |format|
      format.turbo_stream
    end
  end


  def preview
    @world   = World.find(params[:id])
    @filters = params.permit(:name, :pet_type_id)

    @active_pet_ids = UserExploration.joins(:user_pets)
                                     .where(user_explorations: { completed_at: nil, user_id: current_user.id })
                                     .pluck('user_pets.id')

    pets = current_user.user_pets.includes(pet: :pet_types)
    pets = pets.where('user_pets.name ILIKE ?', "%#{@filters[:name]}%") if @filters[:name].present?
    if @filters[:pet_type_id].present?
      pets = pets.joins(pet: :pet_types).where(pet_types: { id: @filters[:pet_type_id] })
    end
    @user_pets = pets.order(power: :desc).distinct

    respond_to do |format|
      format.turbo_stream
    end
  end

end
