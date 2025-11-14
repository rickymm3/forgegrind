# app/controllers/admin/abilities_controller.rb
class Admin::AbilitiesController < Admin::BaseController
  before_action :set_ability, only: %i[show edit update destroy]

  def index
    @abilities = Ability.order(:name)
  end

  def show; end

  def new
    @ability = Ability.new
    # build a couple of nested slots for the form
    @ability.ability_permissions.build
    @ability.ability_effects.build
  end

  def edit
    # ensure at least one nested slot exists
    @ability.ability_permissions.build if @ability.ability_permissions.empty?
    @ability.ability_effects.build     if @ability.ability_effects.empty?
  end

  def create
    @ability = Ability.new(ability_params)
    if @ability.save
      redirect_to admin_ability_path(@ability), notice: "Ability created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @ability.update(ability_params)
      redirect_to admin_ability_path(@ability), notice: "Ability updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @ability.destroy
    redirect_to admin_abilities_path, notice: "Ability deleted."
  end

  private

  def set_ability
    @ability = Ability.find(params[:id])
  end

  def ability_params
    params.require(:ability).permit(
      :name, :reference, :description, :element_type,
      ability_permissions_attributes: %i[id permitted_type permitted_id _destroy],
      ability_effects_attributes:     %i[id effect_id magnitude duration _destroy]
    )
  end
end
