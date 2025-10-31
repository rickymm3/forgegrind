class Admin::DashboardController < Admin::BaseController
  before_action :load_collections, only: [:index, :grant_items]

  def index; end

  def grant_items
    unless params[:user_id].present?
      flash.now[:alert] = "Please select a user."
      render :index, status: :unprocessable_entity and return
    end

    @selected_user = User.find_by(id: params[:user_id])

    unless @selected_user
      flash.now[:alert] = "Selected user was not found."
      render :index, status: :unprocessable_entity and return
    end

    @selected_user_items = @selected_user.user_items.index_by(&:item_id)

    item_quantities = permitted_item_quantities
    if item_quantities.blank? || item_quantities.values.all? { |quantity| quantity <= 0 }
      flash.now[:alert] = "Enter a quantity for at least one item."
      render :index, status: :unprocessable_entity and return
    end

    ActiveRecord::Base.transaction do
      item_quantities.each do |item_id, quantity|
        next if quantity <= 0

        item = @items_by_id[item_id]
        next unless item

        user_item = @selected_user.user_items.find_or_initialize_by(item_id: item.id)
        user_item.quantity = user_item.quantity.to_i + quantity
        user_item.save!
      end
    end

    redirect_to admin_root_path, notice: "Granted items to #{@selected_user.email}."
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:alert] = "Could not grant items: #{e.message}"
    render :index, status: :unprocessable_entity
  end

  private

  def load_collections
    @users       = User.order(:email)
    @items       = Item.order(:name)
    @items_by_id = @items.index_by(&:id)
    @selected_user_items ||= {}
  end

  def permitted_item_quantities
    items_param = params[:items]
    return {} unless items_param.is_a?(ActionController::Parameters)

    items_param.permit!.to_h.each_with_object({}) do |(key, value), result|
      result[key.to_i] = value.to_i
    end
  end
end
