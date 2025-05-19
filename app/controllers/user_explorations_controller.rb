class UserExplorationsController < ApplicationController
  def complete
    @user_exploration = current_user.user_explorations.find(params[:id])
    @world = @user_exploration.world

    # Find or create the reward item
    item = Item.find_or_create_by!(item_type: @world.reward_item_type) do |i|
      i.name = @world.reward_item_type.titleize
    end

    # Add item to user's inventory
    @user_item = UserItem.add_to_inventory(current_user, item, 1)

    # Optionally clean up completed explorations here:
    @user_exploration.destroy

    respond_to do |format|
      format.turbo_stream
    end
  end

end
