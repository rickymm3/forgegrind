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
  
    # Create new exploration
    @user_exploration = current_user.user_explorations.create!(world: @world, started_at: Time.current)
  
    respond_to do |format|
      format.turbo_stream
    end
  end

end
