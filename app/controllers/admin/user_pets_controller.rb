class Admin::UserPetsController < Admin::BaseController
  before_action :set_user_pet, only: [:show, :edit, :update]

  def index
    @user_pets = UserPet.includes(:user, :pet, :rarity).order("users.email ASC", "pets.name ASC")
  end

  def show
  end

  def edit
  end

  def update
    permitted = user_pet_params

    if update_structured_attributes(@user_pet, permitted) && @user_pet.update(permitted)
      redirect_to admin_user_pet_path(@user_pet), notice: "Pet updated successfully."
    else
      flash.now[:alert] = @user_pet.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user_pet
    @user_pet = UserPet.find(params[:id])
  end

  def user_pet_params
    params.require(:user_pet).permit(
      :name,
      :level,
      :exp,
      :energy,
      :interactions_remaining,
      :asleep_until,
      :hunger,
      :hygiene,
      :boredom,
      :injury_level,
      :mood,
      :playfulness,
      :affection,
      :temperament,
      :curiosity,
      :confidence,
      :needs_updated_at,
      :last_energy_update_at,
      :care_good_days_count,
      :last_good_day,
      :state_flags_json,
      :evolution_journal_json,
      :badges_json
    )
  end

  def update_structured_attributes(user_pet, permitted)
    %i[state_flags evolution_journal badges].each do |attribute|
      json_param = "#{attribute}_json".to_sym
      next unless permitted.key?(json_param)

      raw_value = permitted.delete(json_param)
      next if raw_value.blank?

      begin
        parsed = JSON.parse(raw_value)
        parsed = parsed.to_h if attribute != :badges && parsed.is_a?(Array)
        parsed = parsed.to_a if attribute == :badges && parsed.is_a?(Hash)
        permitted[attribute] = parsed
      rescue JSON::ParserError => e
        user_pet.errors.add(attribute, "Invalid JSON: #{e.message}")
        return false
      end
    end
    true
  end
end
