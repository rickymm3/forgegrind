class StoreController < ApplicationController
  before_action :authenticate_user!

  VALID_TABS = %w[items eggs].freeze
  PET_CARE_STORE_ITEMS = [
    { item_type: "treat", price: 25, quantity: 1, currency_key: :coins },
    { item_type: "frisbee", price: 60, quantity: 1, currency_key: :coins },
    { item_type: "blanket", price: 60, quantity: 1, currency_key: :coins },
    { item_type: "map", price: 80, quantity: 1, currency_key: :coins },
    { item_type: "soap", price: 90, quantity: 1, currency_key: :coins },
    { item_type: "rainbow_fruit", price: 150, quantity: 1, currency_key: :coins, highlighted: true },
    { item_type: "rainbow_fruit", price: 20, quantity: 1, currency_key: :diamonds },

    # Extended care catalog
    { item_type: "bone", price: 80, quantity: 1, currency_key: :coins },
    { item_type: "bouncy_ball", price: 120, quantity: 1, currency_key: :coins },
    { item_type: "pet_carnival_pass", price: 400, quantity: 1, currency_key: :coins, highlighted: true },

    { item_type: "spa_soap", price: 110, quantity: 1, currency_key: :coins },
    { item_type: "deluxe_bath_kit", price: 220, quantity: 1, currency_key: :coins },

    { item_type: "hearty_meal", price: 140, quantity: 1, currency_key: :coins },
    { item_type: "gourmet_feast", price: 260, quantity: 1, currency_key: :coins },

    { item_type: "plush_blanket", price: 130, quantity: 1, currency_key: :coins },
    { item_type: "weighted_blanket", price: 240, quantity: 1, currency_key: :coins },

    { item_type: "first_aid_kit", price: 150, quantity: 1, currency_key: :coins },
    { item_type: "deluxe_medpack", price: 280, quantity: 1, currency_key: :coins }
  ].freeze

  def index
    @active_tab = params[:tab].presence_in(VALID_TABS) || "items"
    @selected_item_type = params[:item_type].presence
    @currency_balances = helpers.currency_balances_for(current_user)
    load_tab_dependencies
  end

  def purchase_item
    offer = pet_care_item_offers.find { |entry| entry[:item_type] == params[:item_type].to_s }
    unless offer
      redirect_to store_path(tab: "items"), alert: "That item is no longer available."
      return
    end

    price = offer[:price].to_i
    currency = offer[:currency] || Currency.find_by_key(:coins)
    unless currency
      redirect_to store_path(tab: "items"), alert: "Unknown currency."
      return
    end

    balance = current_user.currency_balance(currency)
    quantity = offer[:quantity].to_i

    if balance < price
      respond_to do |format|
        format.turbo_stream do
          @currency_balances = currency_balances_for(current_user)
          @purchase_error = "Not enough #{currency.name.downcase}."
          render :purchase_item, status: :unprocessable_entity
        end
        format.html do
          redirect_to store_path(tab: "items"), alert: "Not enough #{currency.name.downcase}."
        end
      end
      return
    end

    ActiveRecord::Base.transaction do
      current_user.debit_currency!(currency, price)
      UserItem.add_to_inventory(current_user, offer[:item], quantity)
    end

    respond_to do |format|
      format.turbo_stream do
        @currency_balances = helpers.currency_balances_for(current_user)
        @purchased_offer = offer
        render :purchase_item
      end
      format.html do
        redirect_to store_path(tab: "items"),
                    notice: "#{offer[:item].name} x#{quantity} purchased for #{price} #{currency.name}."
      end
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound, ActiveRecord::Rollback => e
    Rails.logger.warn("[Store] purchase failed: #{e.class} - #{e.message}")
    respond_to do |format|
      format.turbo_stream do
        @currency_balances = helpers.currency_balances_for(current_user)
        @purchase_error = "Unable to complete purchase."
        render :purchase_item
      end
      format.html { redirect_to store_path(tab: "items"), alert: "Unable to complete purchase." }
    end
  end

  private

  def load_tab_dependencies
    case @active_tab
    when "items"
      @pet_care_offers = pet_care_item_offers
      @selected_offer = @pet_care_offers.find { |entry| entry[:item_type] == @selected_item_type }
    when "eggs"
      @eggs = Egg.enabled.includes(:currency, egg_item_costs: :item)
      @highlighted_egg_id = nil
    end
  end

  def pet_care_item_offers
    @pet_care_item_offers ||= begin
      definitions = PET_CARE_STORE_ITEMS
      items = Item.where(item_type: definitions.map { |entry| entry[:item_type] }).index_by(&:item_type)
      definitions.filter_map do |definition|
        item = items[definition[:item_type]]
        next unless item

        currency = Currency.lookup(definition[:currency_key] || definition[:currency])
        next unless currency

        definition.merge(item: item, currency: currency)
      end
    end
  end
end
