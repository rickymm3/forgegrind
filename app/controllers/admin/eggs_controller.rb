class Admin::EggsController < Admin::BaseController
  before_action :set_egg, only: %i[show edit update destroy]
  before_action :prepare_item_costs, only: %i[edit]
  before_action :load_item_options, only: %i[edit]

  def index
    @eggs = Egg.order(:id)
  end

  def show; end

  def new
    @egg = Egg.new
    prepare_item_costs
    load_item_options
  end

  def edit; end

  def create
    @egg = Egg.new(egg_params)
    if @egg.save
      redirect_to admin_egg_path(@egg), notice: "Egg was successfully created."
    else
      prepare_item_costs
      load_item_options
      render :new, status: :unprocessable_entity
    end
  end

  def update
    purge_image(@egg) if remove_image_param?(:egg)
    if @egg.update(egg_params)
      redirect_to admin_egg_path(@egg), notice: "Egg was successfully updated."
    else
      load_item_options
      prepare_item_costs
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @egg.destroy
    redirect_to admin_eggs_path, notice: "Egg was successfully deleted."
  end

  def update_hatch_pets
    @egg = Egg.find(params[:id])
    pet_weights = params.fetch(:pet_weights, {})

    Egg.transaction do
      pet_weights.each do |pet_id, attrs|
        pet = @egg.pets.find(pet_id)
        if remove_param?(attrs[:remove])
          pet.update!(egg_id: nil)
        else
          weight = attrs[:weight].to_i
          pet.update!(hatch_weight: [weight, 1].max)
        end
      end

      new_pet_id = params[:new_pet_id].presence
      if new_pet_id
        pet = Pet.find(new_pet_id)
        pet.update!(
          egg: @egg,
          hatch_weight: params[:new_pet_weight].presence || pet.hatch_weight
        )
      end
    end

    redirect_to admin_egg_path(@egg), notice: "Hatch table updated."
  end

  private

  def set_egg
    @egg = Egg.find(params[:id])
  end

  def egg_params
    params.require(:egg).permit(
      :name,
      :enabled,
      :image,
      :currency_id,
      :cost_amount,
      :hatch_duration,
      egg_item_costs_attributes: %i[id item_id quantity _destroy]
    )
  end

  def remove_image_param?(resource_key)
    ActiveModel::Type::Boolean.new.cast(params.dig(resource_key, :remove_image))
  end

  def purge_image(record)
    record.image.purge_later if record.image.attached?
  end

  def remove_param?(value)
    ActiveModel::Type::Boolean.new.cast(value)
  end

  def prepare_item_costs
    egg = @egg || @egg = Egg.new
    egg.egg_item_costs.build if egg.egg_item_costs.empty? || egg.egg_item_costs.none? { |cost| cost.item_id.blank? }
  end

  def load_item_options
    @item_options = Item.order(:name)
  end
end
