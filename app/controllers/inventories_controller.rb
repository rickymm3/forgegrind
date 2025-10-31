class InventoriesController < ApplicationController
  before_action :authenticate_user!

  def show
    @containers = current_user.user_containers
                               .includes(:chest_type)
                               .joins(:chest_type)
                               .order("chest_types.min_level ASC")
    @items = current_user.user_items
                         .includes(:item)
                         .joins(:item)
                         .order("items.name ASC")

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end
end
