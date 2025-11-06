class StoreController < ApplicationController
  before_action :authenticate_user!

  VALID_TABS = %w[items eggs].freeze

  def index
    @active_tab = params[:tab].presence_in(VALID_TABS) || "items"
    load_tab_dependencies
  end

  private

  def load_tab_dependencies
    case @active_tab
    when "eggs"
      @eggs = Egg.enabled.includes(:currency, egg_item_costs: :item)
      @highlighted_egg_id = nil
    end
  end
end
