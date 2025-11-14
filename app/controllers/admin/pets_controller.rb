class Admin::PetsController < Admin::BaseController
  before_action :set_pet, only: %i[show edit update destroy]

  def index
    @pets = Pet.includes(:egg).order(:id)
  end

  def show; end

  def new
    @pet = Pet.new
  end

  def edit
    load_evolution_form_data
  end

  def create
    @pet = Pet.new(pet_params)
    if @pet.save
      redirect_to admin_pet_path(@pet), notice: "Pet was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    purge_image(@pet) if remove_image_param?(:pet)
    if @pet.update(pet_params)
      redirect_to admin_pet_path(@pet), notice: "Pet was successfully updated."
    else
      load_evolution_form_data
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @pet.user_pets.exists?
      copies = helpers.pluralize(@pet.user_pets.count, "player-owned copy")
      redirect_to admin_pet_path(@pet),
                  alert: "Cannot delete this pet while #{copies} still exist. Retire or migrate them first."
    else
      @pet.destroy
      redirect_to admin_pets_path, notice: "Pet was successfully deleted."
    end
  end

  private

  def set_pet
    @pet = Pet.find(params[:id])
  end

  def load_evolution_form_data
    @evolution_rules = @pet.evolution_rules_as_parent.includes(:child_pet, :fallback_child_pet, :required_item).order(:priority, :id)
  end

  def pet_params
    params.require(:pet).permit(
      :name,
      :rarity_id,
      :description,
      :special_ability_id,
      :image,
      :power,
      :hp,
      :atk,
      :def,
      :sp_atk,
      :sp_def,
      :speed
    )
  end

  def remove_image_param?(resource_key)
    ActiveModel::Type::Boolean.new.cast(params.dig(resource_key, :remove_image))
  end

  def purge_image(record)
    record.image.purge_later if record.image.attached?
  end
end
