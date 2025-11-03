class InventoriesController < ApplicationController
  before_action :authenticate_user!

  helper ItemsHelper
  helper InventoriesHelper

  def show
    load_inventory
  end

  def container_panel
    load_inventory

    if params[:cancel].present?
      render_detail_panel(state: :idle) and return
    end

    key = params[:key].to_s
    container = @containers.find { |record| record.chest_type&.key == key }
    chest = container&.chest_type || ChestType.includes(:default_loot_table).find_by!(key: key)
    count = container&.count.to_i

    render_detail_panel(
      state: :container,
      chest: chest,
      container_count: count,
      close_path: container_panel_inventory_path
    )
  end

  def item_panel
    load_inventory

    if params[:cancel].present?
      render_detail_panel(state: :idle) and return
    end

    user_item = @items.find { |record| record.id == params[:item_id].to_i }
    raise ActiveRecord::RecordNotFound, "Item not found" unless user_item

    item = user_item.item
    metadata = item_metadata(item)

    render_detail_panel(
      state: :item,
      user_item: user_item,
      item: item,
      metadata: metadata,
      close_path: item_panel_inventory_path
    )
  end

  private

  def load_inventory
    @containers = current_user.user_containers
                               .includes(:chest_type)
                               .joins(:chest_type)
                               .order("chest_types.min_level ASC")
    @items = current_user.user_items
                         .includes(:item)
                         .joins(:item)
                         .order("items.name ASC")
  end

  def render_detail_panel(state:, close_path: container_panel_inventory_path, **locals)
    panel_locals = {
      state: state,
      close_path: close_path,
      **locals
    }

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "inventory-detail-panel",
          partial: "inventories/detail_panel",
          formats: :html,
          locals: panel_locals
        )
      end
      format.html do
        load_inventory unless defined?(@containers) && defined?(@items)
        render :show
      end
    end
  end

  def item_metadata(item)
    view_context.inventory_item_metadata(item)
  end
end
