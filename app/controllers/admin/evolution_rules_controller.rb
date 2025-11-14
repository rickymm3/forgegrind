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
    whitelisted = params.require(:evolution_rule).permit(
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
      :guard_json,
      :success_chance_percent,
      :fallback_child_pet_id,
      guard_badge_keys: [],
      required_badges: []
    ).to_h

    whitelisted["required_badges"] ||= []

    badge_keys = Array(whitelisted.delete("guard_badge_keys")).reject(&:blank?)

    chance = whitelisted["success_chance_percent"].presence || 100
    whitelisted["success_chance_percent"] = chance.to_i

    guard_value = whitelisted["guard_json"]
    guard_hash =
      if guard_value.is_a?(Hash)
        guard_value
      elsif guard_value.is_a?(String) && guard_value.present?
        begin
          JSON.parse(guard_value)
        rescue JSON::ParserError
          guard_value
        end
      else
        {}
      end

    if guard_hash.is_a?(Hash)
      clean_guard = lambda do |hash|
        hash["all"] = Array(hash["all"]).reject { |cond| cond.is_a?(Hash) && cond["type"].to_s == "badge_unlocked" }
        hash["any"] = Array(hash["any"]).reject { |cond| cond.is_a?(Hash) && cond["type"].to_s == "badge_unlocked" }
        hash.delete("all") if hash["all"].blank?
        hash.delete("any") if hash["any"].blank?
        hash
      end

      guard_hash = clean_guard.call(guard_hash)

      if badge_keys.any?
        guard_hash["all"] ||= []
        guard_hash["all"].concat(badge_keys.map { |key| { "type" => "badge_unlocked", "key" => key } })
      end

      whitelisted["guard_json"] = guard_hash
    else
      whitelisted["guard_json"] = guard_hash
    end

    whitelisted
  end
end
