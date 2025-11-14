class Admin::WorldsController < Admin::BaseController
  before_action :set_world, only: %i[show edit update destroy]

  def index
    @worlds = World.order(:name)
  end

  def show; end

  def new
    @world = World.new(duration: 600, reward_item_type: "gold")
  end

  def edit; end

  def create
    @world = World.new(world_params)
    if @world.save
      redirect_to admin_world_path(@world), notice: "Zone created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @world.update(world_params)
      redirect_to admin_world_path(@world), notice: "Zone updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @world.destroy
    redirect_to admin_worlds_path, notice: "Zone deleted."
  end

  private

  def set_world
    @world = World.find(params[:id])
  end

  def world_params
    permitted = params.require(:world).permit(
      :name,
      :duration,
      :reward_item_type,
      :enabled,
      :diamond_reward,
      :upgraded_on_clear,
      :drop_table_override_key,
      :upgrade_drop_table_override_key,
      :rotation_active,
      :rotation_weight,
      :rotation_starts_at,
      :rotation_ends_at,
      :special_traits_input,
      :required_pet_abilities_input,
      :upgrade_trait_keys_input,
      :upgrade_required_pet_abilities_input
    )

    permitted[:special_traits] = split_lines(permitted.delete(:special_traits_input))
    permitted[:required_pet_abilities] = split_lines(permitted.delete(:required_pet_abilities_input))
    permitted[:upgrade_trait_keys] = split_lines(permitted.delete(:upgrade_trait_keys_input))
    permitted[:upgrade_required_pet_abilities] = split_lines(permitted.delete(:upgrade_required_pet_abilities_input))

    permitted
  end

  def split_lines(value)
    Array(value.to_s.split(/\r?\n|,/).map(&:strip).reject(&:blank?))
  end
end
