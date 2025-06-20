class WorldsController < ApplicationController
  def index
    @worlds        = World.active.order(:id)
    @unlocked_ids  = current_user.unlocked_worlds.pluck(:id)
  end
end
