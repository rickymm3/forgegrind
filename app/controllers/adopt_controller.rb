class AdoptController < ApplicationController
  before_action :authenticate_user!

  def index
    @eggs = Egg.includes(egg_item_costs: :item).all

    # Only fetch items used in Egg costs for this page
    relevant_item_ids = EggItemCost.distinct.pluck(:item_id)
    @user_items = current_user.user_items.includes(:item).where(item_id: relevant_item_ids)
  end
end
