class ItemsController < ApplicationController
  before_action :authenticate_user!

  def index
    # 1) Fetch all UserItem records for the current user
    @user_items = current_user.user_items.includes(:item)

    # 2) Load the YAML once and freeze it for lookups
    raw_details = YAML.load_file(Rails.root.join("config/item_details.yml"))
                      .with_indifferent_access

    # 3) Build a hash: item_type => details_hash (description + mods)
    @item_details = raw_details
  end
end
