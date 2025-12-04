class UsersController < ApplicationController
  before_action :authenticate_user!

  def show
    @user = current_user
    @stat = @user.ensure_user_stat
    @currency_balances = helpers.currency_balances_for(@user)
    @attribute_stats = [
      { label: "HP",         key: :hp_level },
      { label: "Attack",     key: :attack_level },
      { label: "Defense",    key: :defense_level },
      { label: "Luck",       key: :luck_level },
      { label: "Attunement", key: :attunement_level }
    ]
  end
end
