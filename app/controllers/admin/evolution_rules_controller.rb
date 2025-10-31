# app/controllers/admin/evolution_rules_controller.rb
class Admin::EvolutionRulesController < Admin::BaseController
  before_action :set_rule, only: %i[show edit update destroy]

  def index
    @rules = EvolutionRule.includes(:parent_pet, :child_pet).order(priority: :desc, trigger_level: :asc, id: :asc)
  end

  def show; end

  def new
    @rule = EvolutionRule.new
  end

  def edit; end

  def create
    @rule = EvolutionRule.new(rule_params)
    if @rule.save
      redirect_to admin_evolution_rule_path(@rule), notice: "Evolution rule created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @rule.update(rule_params)
      redirect_to admin_evolution_rule_path(@rule), notice: "Evolution rule updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @rule.destroy
    redirect_to admin_evolution_rules_path, notice: "Evolution rule deleted."
  end

  # GET /admin/evolution_rules/dry_run?user_pet_id=...&level=...&event=...
  def dry_run
    @user_pet = params[:user_pet_id].present? ? UserPet.find_by(id: params[:user_pet_id]) : nil
    @level    = params[:level].presence
    @event    = params[:event].presence
    @result   = nil

    if @user_pet
      engine = EvolutionEngine.new(user_pet: @user_pet)
      @result = if @event.present?
                  engine.evaluate_on_event!(event_key: @event)
                elsif @level.present?
                  engine.evaluate_for(level: @level.to_i)
                else
                  nil
                end
    end
  end

  private

  def set_rule
    @rule = EvolutionRule.find(params[:id])
  end

  def rule_params
    params.require(:evolution_rule).permit(
      :parent_pet_id,
      :child_pet_id,
      :required_item_id,
      :trigger_level,
      :window_min_level,
      :window_max_level,
      :window_event,
      :priority,
      :one_shot,
      :seasonal_tag,
      :notes,
      :guard_json
    ).tap do |whitelisted|
      # guard_json may come from a textarea; ensure it's parsed JSON if given as a string
      if whitelisted[:guard_json].is_a?(String)
        begin
          parsed = JSON.parse(whitelisted[:guard_json])
          whitelisted[:guard_json] = parsed
        rescue JSON::ParserError
          # keep as string and let model save fail validation if needed
        end
      end
    end
  end
end
