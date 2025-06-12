class ExplorationsController < ApplicationController
  def index
    @worlds = World.all
    @user_explorations = current_user.user_explorations.includes(:world).where(completed_at: nil)
  end

  def start
    @world = World.find(params[:id])
  
    # If there’s already an active exploration, just re-render its countdown
    existing = current_user.user_explorations.find_by(world: @world, completed_at: nil)
    if existing.present?
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(
            "exploration_#{@world.id}",
            partial: "explorations/countdown",
            locals: { user_exploration: existing }
          )
        end
      end
      return
    end
  
    # Require at least one pet selected
    user_pet_ids = Array(params[:user_pet_ids]).map(&:to_i).uniq
    if user_pet_ids.empty?
      flash[:alert] = "Please select at least one pet to explore."
      redirect_to explorations_path and return
    end

    # Ensure no more than 3 and no overlapping active pets
    active_pet_ids = current_user.user_explorations
                                 .joins(:user_pets)
                                 .where(completed_at: nil)
                                 .pluck('user_pets.id')
  
    if user_pet_ids.size > 3 || (user_pet_ids & active_pet_ids).any?
      head :unprocessable_entity and return
    end
  
    # Kick off the exploration
    user_pet_ids   = user_pet_ids.first(3)
    @user_exploration = current_user.user_explorations.create!(world: @world, started_at: Time.current)
    @user_exploration.user_pets << current_user.user_pets.where(id: user_pet_ids)
  
    respond_to do |format|
      format.turbo_stream
    end
  end

  # POST /explorations/:id/complete
  def complete
    @user_exploration = current_user.user_explorations.find(params[:id])
    return head :unprocessable_entity if @user_exploration.completed_at

    reward = GameConfig.exp_for(@user_exploration.world.key)

    @user_exploration.user_pets.each do |up|
      # add reward, cap at EXP_PER_LEVEL, discard any overflow
      new_exp = [up.exp.to_i + reward, UserPet::EXP_PER_LEVEL].min
      up.update!(exp: new_exp)
    end

    @user_exploration.update!(completed_at: Time.current)

    respond_to do |format|
      format.turbo_stream
      format.html do
        redirect_to explorations_path,
                    notice: "Exploration complete! Each pet gained #{reward} EXP."
      end
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
