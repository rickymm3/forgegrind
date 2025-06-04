class UserExplorationsController < ApplicationController
  def complete
    @user_exploration = current_user.user_explorations.find(params[:id])
    @world = @user_exploration.world
    slug = @world.name.parameterize(separator: "_")

    # Determine bucket name based on this world’s ID (e.g., "world_1_chest_common")
    bucket_name = "bucket_#{slug}"

    # Open that bucket—awards all guaranteed items + any weighted drops
    @awarded_items = UserItem.open_bucket(user: current_user, bucket_name: bucket_name)

    @user_exploration.destroy

    respond_to do |format|
      format.turbo_stream
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
