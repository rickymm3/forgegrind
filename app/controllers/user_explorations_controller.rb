class UserExplorationsController < ApplicationController
  # POST /user_explorations/:id/complete
  def complete
    @user_exploration = current_user.user_explorations.find(params[:id])
    @world            = @user_exploration.world
  
    # build a slug from the world name to look up EXP
    slug    = @world.name.parameterize(separator: "_")
    @reward = GameConfig.exp_for(slug)
  
    @user_pets = @user_exploration.user_pets.to_a
    @user_pets.each do |up|
      new_exp = [up.exp.to_i + @reward, UserPet::EXP_PER_LEVEL].min
      up.update!(exp: new_exp)
    end
  
    bucket_name    = "bucket_#{slug}"
    @awarded_items = UserItem.open_bucket(user: current_user, bucket_name: bucket_name)
  
    @user_exploration.destroy
  
    respond_to do |format|
      format.turbo_stream
      format.html do
        redirect_to explorations_path,
                    notice: "Exploration complete! Each pet gained #{@reward} EXP."
      end
    end
  end


  def ready
    # Use :id or, if that’s nil, :user_exploration_id
    exploration_id = params[:id] || params[:user_exploration_id]
    @user_exploration = current_user.user_explorations.find(exploration_id)

    respond_to do |format|
      format.turbo_stream
    end
  end


end
