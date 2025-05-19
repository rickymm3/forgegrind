class Admin::EggsController < Admin::BaseController
  before_action :set_egg, only: %i[show edit update destroy]

  def index
    @eggs = Egg.order(:id)
  end

  def show; end

  def new
    @egg = Egg.new
  end

  def edit; end

  def create
    @egg = Egg.new(egg_params)
    if @egg.save
      redirect_to admin_egg_path(@egg), notice: "Egg was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @egg.update(egg_params)
      redirect_to admin_egg_path(@egg), notice: "Egg was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @egg.destroy
    redirect_to admin_eggs_path, notice: "Egg was successfully deleted."
  end

  def assign_pets
    @egg = Egg.find(params[:id])
    selected_pet_ids = params[:pet_ids] || []
  
    # Unassign all current pets from this egg
    Pet.where(egg_id: @egg.id).update_all(egg_id: nil)
  
    # Assign selected pets
    Pet.where(id: selected_pet_ids).update_all(egg_id: @egg.id)
  
    redirect_to admin_egg_path(@egg), notice: "Pets updated for this egg."
  end

  private

  def set_egg
    @egg = Egg.find(params[:id])
  end

  def egg_params
    params.require(:egg).permit(:name, :enabled, :description)
  end
end
