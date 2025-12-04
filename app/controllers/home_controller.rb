class HomeController < ApplicationController
  def index
    @starter_egg = Egg.find_by(name: "Starter Egg")
    return unless user_signed_in?

    @active_starter_egg = current_user.user_eggs.unhatched.includes(:egg).find_by(egg: @starter_egg) if @starter_egg
  end
end
