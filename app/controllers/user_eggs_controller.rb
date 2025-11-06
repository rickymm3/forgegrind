class UserEggsController < ApplicationController
  before_action :authenticate_user!

  def show
    @user_egg = current_user.user_eggs.includes(:egg).find(params[:id])

    if turbo_frame_request?
      frame_id = request.headers["Turbo-Frame"]
      context = params[:context].presence&.to_sym || :page
      helpers_proxy = view_context

      if frame_id == helpers_proxy.egg_action_panel_dom_id(@user_egg)
        render partial: "user_eggs/action_panel",
               locals: {
                 user_egg: @user_egg,
                 context: context,
                 state: @user_egg.status
               }
      elsif frame_id == helpers_proxy.egg_card_dom_id(@user_egg)
        streams = []

        streams << helpers_proxy.turbo_stream.replace(
          frame_id,
          helpers_proxy.render("user_eggs/inventory_card", user_egg: @user_egg)
        )

        streams << helpers_proxy.turbo_stream.update(
          helpers_proxy.egg_info_dom_id(@user_egg),
          helpers_proxy.render(
            "user_eggs/info_body",
            user_egg: @user_egg,
            context: context,
            status: @user_egg.status
          )
        )

        streams << helpers_proxy.turbo_stream.replace(
          helpers_proxy.egg_action_panel_dom_id(@user_egg),
          helpers_proxy.render(
            "user_eggs/action_panel",
            user_egg: @user_egg,
            context: context,
            state: @user_egg.status
          )
        )

        render turbo_stream: streams
      elsif frame_id == helpers_proxy.egg_info_dom_id(@user_egg)
        render partial: "user_eggs/info_body",
               locals: {
                 user_egg: @user_egg,
                 context: context
               }
      else
        render partial: "user_eggs/info_panel",
               locals: {
                 user_egg: @user_egg,
                 context: context
               }
      end
      return
    end

    @egg = @user_egg.egg
  end

  def create
    egg = Egg.find(params[:egg_id])
    @egg = egg
    origin = params[:origin].presence
  
    unless current_user.can_afford_egg?(egg)
      respond_to do |format|
        format.turbo_stream do
          if origin == "store"
            @egg = egg
            render :create_from_store_failure, status: :unprocessable_entity
          else
            head :unprocessable_entity
          end
        end
        format.html do
          destination = origin == "store" ? store_path(tab: "eggs") : adopt_path
          redirect_to destination, alert: "You don't have the required items."
        end
      end
      return
    end
  
    UserEgg.transaction do
      current_user.spend_currency_for_egg!(egg)
      current_user.spend_items_for_egg!(egg)
      current_user.user_eggs.create!(egg: egg, hatched: false)
    end
  
    respond_to do |format|
      format.turbo_stream do
        if origin == "store"
          @eggs = Egg.enabled.includes(:currency, egg_item_costs: :item)
          @highlighted_egg_id = egg.id
          render :create_from_store
        else
          render :create
        end
      end
      format.html do
        destination = origin == "store" ? store_path(tab: "eggs") : adopt_path
        redirect_to destination, notice: "You adopted a #{egg.name}!"
      end
    end
  end
  

  def incubate
    @user_egg = current_user.user_eggs.find(params[:id])
    context = params[:context].presence&.to_sym || :page
    return if @user_egg.hatched? || @user_egg.hatch_started_at.present?

    @user_egg.update!(hatch_started_at: Time.current)

    respond_to do |format|
      format.turbo_stream { render :incubate, locals: { context: context } }
      format.html { redirect_to user_pets_path }
    end
  end

  def mark_ready
    @user_egg = current_user.user_eggs.find(params[:id])
    context = params[:context].presence&.to_sym || :page

    unless @user_egg.hatching? && @user_egg.hatch_time_remaining <= 2
      head :unprocessable_entity
      return
    end

    respond_to do |format|
      format.turbo_stream { render :mark_ready, locals: { context: context } }
      format.html { redirect_to user_pets_path }

    end
  end

  def hatch
    @user_egg = current_user.user_eggs.find(params[:id])
    @user_pet = nil

    UserEgg.transaction do
      @user_egg.lock!
      raise ActiveRecord::RecordInvalid.new(@user_egg) if @user_egg.hatched?

      @user_egg.update!(hatched: true)
      pet = @user_egg.egg.random_pet

      random_thought = PetThought.order("RANDOM()").first || PetThought.first
      raise ActiveRecord::RecordInvalid.new(@user_egg) unless random_thought

      @user_pet = current_user.user_pets.create!(
        pet:         pet,
        egg:         @user_egg.egg,
        name:        pet.name,
        rarity:      pet.rarity,
        power:       pet.power,
        playfulness: rand(1..10),
        affection:   rand(1..10),
        temperament: rand(1..10),
        curiosity:   rand(1..10),
        confidence:  rand(1..10),
        pet_thought: random_thought
      )
    end

    @egg_count = current_user.user_eggs.unhatched.count
    @pet_count = current_user.user_pets.active.count

    respond_to do |format|
      format.turbo_stream { render :hatch, locals: { context: params[:context].presence&.to_sym || :page } }
      format.html { redirect_to user_pet_path(@user_pet), notice: "You hatched #{@user_pet.pet.name}!" }
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Egg hatch failed: #{e.message}")
    respond_to do |format|
      format.turbo_stream { head :unprocessable_entity }
      format.html { redirect_to user_pets_path(collection: "eggs"), alert: "Unable to hatch this egg right now." }
    end
  end

  # def hatch
  #   @user_egg = current_user.user_eggs.find(params[:id])
  #   @egg_frame_id = "user_egg_hatch_#{@user_egg.id}" # Define the frame ID for the main page

  #   UserEgg.transaction do
  #     @user_egg.update!(hatched: true)
  #     pet = @user_egg.egg.random_pet # Assuming egg.random_pet is defined
  #     @user_pet = current_user.user_pets.create!(
  #       pet:    pet,
  #       egg:    @user_egg.egg,
  #       name:   pet.name,
  #       rarity: pet.rarity,
  #       power:  pet.power
  #     )
  #   end

  #   # Respond with turbo_stream directly
  #   respond_to do |format|
  #     format.html { redirect_to nursery_path } # Fallback for non-turbo requests
  #     format.turbo_stream do
  #       # This will implicitly render user_eggs/hatch.turbo_stream.haml
  #       # or you can explicitly render:
  #       # render turbo_stream: [
  #       #   turbo_stream.update(@egg_frame_id, partial: "nursery/hatched", locals: { user_egg: @user_egg }),
  #       #   turbo_stream.update("hatch-modal-content-frame", partial: "nursery/hatch_modal_content", locals: { pet: @user_pet.pet, egg: @user_egg.egg })
  #       # ]
  #     end
  #   end
  # rescue ActiveRecord::RecordNotFound
  #   redirect_to nursery_path, alert: "Egg not found."
  # rescue StandardError => e
  #   Rails.logger.error "Hatching error: #{e.message}"
  #   respond_to do |format|
  #     format.html { redirect_to nursery_path, alert: "Error hatching egg." }
  #     format.turbo_stream { head :unprocessable_entity } # Or render an error stream
  #   end
  # end

end
