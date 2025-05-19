class NurseryController < ApplicationController
  before_action :authenticate_user!

  def index
    @user_eggs = current_user.user_eggs.includes(:egg)
  end

end
