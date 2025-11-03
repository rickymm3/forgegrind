class Admin::SpecialAbilitiesController < Admin::BaseController
  before_action :set_special_ability, only: %i[show edit update destroy]

  def index
    @special_abilities = SpecialAbility.ordered
  end

  def show; end

  def new
    @special_ability = SpecialAbility.new
  end

  def edit; end

  def create
    @special_ability = SpecialAbility.new(special_ability_params)
    if @special_ability.save
      redirect_to admin_special_ability_path(@special_ability), notice: "Special ability created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @special_ability.update(special_ability_params)
      redirect_to admin_special_ability_path(@special_ability), notice: "Special ability updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @special_ability.destroy
    redirect_to admin_special_abilities_path, notice: "Special ability deleted."
  end

  private

  def set_special_ability
    @special_ability = SpecialAbility.find(params[:id])
  end

  def special_ability_params
    params.require(:special_ability).permit(
      :reference,
      :name,
      :tagline,
      :description,
      :encounter_tags_csv,
      :metadata_json
    )
  end
end
