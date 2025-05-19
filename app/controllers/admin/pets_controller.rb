class Admin::PetsController < Admin::BaseController
  before_action :set_pet, only: %i[show edit update destroy]

  def index
    @pets = Pet.includes(:egg).order(:id)
  end

  def show; end

  def new
    @pet = Pet.new
  end

  def edit; end

  def create
    @pet = Pet.new(pet_params)
    if @pet.save
      redirect_to admin_pet_path(@pet), notice: "Pet was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @pet.update(pet_params)
      redirect_to admin_pet_path(@pet), notice: "Pet was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @pet.destroy
    redirect_to admin_pets_path, notice: "Pet was successfully deleted."
  end

  private

  def set_pet
    @pet = Pet.find(params[:id])
  end

  def pet_params
    params.require(:pet).permit(:name, :rarity_id, :egg_id, :description)
  end
end
