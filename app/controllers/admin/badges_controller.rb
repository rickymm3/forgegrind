class Admin::BadgesController < Admin::BaseController
  TRACKERS = {
    hunger: "hunger_score",
    hygiene: "hygiene_score",
    boredom: "boredom_score",
    injury: "injury_score",
    mood: "mood_score"
  }.freeze

  before_action :set_badge, only: %i[edit update destroy]

  def index
    @badges = BadgeConfigStore.badges
  end

  def new
    @badge_key = ""
    @badge = default_badge_payload
  end

  def edit; end

  def create
    @badge_key = permitted_key
    @badge = build_payload
    BadgeConfigStore.upsert!(@badge_key, @badge)
    redirect_to admin_badges_path, notice: "Badge created."
  rescue StandardError => e
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_entity
  end

  def update
    original_key = params[:id]
    @badge_key = permitted_key
    @badge = build_payload
    BadgeConfigStore.upsert!(@badge_key, @badge)
    BadgeConfigStore.delete!(original_key) if original_key != @badge_key
    redirect_to admin_badges_path, notice: "Badge updated."
  rescue StandardError => e
    flash.now[:alert] = e.message
    render :edit, status: :unprocessable_entity
  end

  def destroy
    BadgeConfigStore.delete!(params[:id])
    redirect_to admin_badges_path, notice: "Badge deleted."
  end

  private

  def set_badge
    @badge_key = params[:id]
    @badge = BadgeConfigStore.find(@badge_key)
    unless @badge
      redirect_to admin_badges_path, alert: "Badge not found."
      return
    end
  end

  def permitted_key
    key = params.require(:badge).fetch(:key, "").parameterize(separator: "_")
    raise ArgumentError, "Badge key is required." if key.blank?

    key
  end

  def build_payload
    attrs = params.require(:badge).permit(
      :label,
      :description,
      :color,
      :transfers_on_level_up,
      :category
    )
    raise ArgumentError, "Label is required." if attrs[:label].blank?

    payload = {
      "label" => attrs[:label],
      "description" => attrs[:description],
      "color" => attrs[:color],
      "transfers_on_level_up" => ActiveModel::Type::Boolean.new.cast(attrs[:transfers_on_level_up]),
      "category" => attrs[:category].presence || "care",
      "conditions" => build_conditions,
      "overrides" => {
        "remove" => Array(params[:badge][:remove_badges]).reject(&:blank?)
      }
    }

    payload
  end

  def build_conditions
    tracker_conditions = []
    tracker_params = params[:badge][:trackers] || {}
    tracker_params.each do |key, tracker|
      enabled = ActiveModel::Type::Boolean.new.cast(tracker[:enabled])
      next unless enabled

      comparison = tracker[:comparison] == "at_most" ? "tracker_at_most" : "tracker_at_least"
      value = tracker[:value].presence || tracker[:threshold].presence
      next unless value

      tracker_conditions << {
        "type" => comparison,
        "key" => TRACKERS[key.to_sym] || key,
        "value" => value.to_i
      }
    end

    meta_conditions = build_meta_conditions
    { "all" => tracker_conditions + meta_conditions }
  end

  def build_meta_conditions
    raw = params.dig(:badge, :meta_conditions) || {}
    raw.values.map do |condition|
      type = condition[:type].presence
      key = condition[:key].presence
      value = condition[:value].presence
      next unless type

      entry = { "type" => type }
      entry["key"] = key if key
      entry["value"] = value if value
      entry
    end.compact
  end

  def default_badge_payload
    {
      "label" => "",
      "description" => "",
      "color" => "",
      "transfers_on_level_up" => false,
      "category" => "care",
      "conditions" => { "all" => [] },
      "overrides" => { "remove" => [] }
    }
  end

  helper_method :tracker_options, :tracker_settings, :available_badges, :meta_condition_rows, :meta_condition_types

  def tracker_options
    TRACKERS.keys
  end

  def tracker_settings
    tracker_options.index_with do |key|
      existing = Array(@badge&.dig("conditions", "all")).find do |condition|
        condition["key"] == TRACKERS[key]
      end

      {
        enabled: existing.present?,
        comparison: existing&.fetch("type", "tracker_at_least") == "tracker_at_most" ? "at_most" : "at_least",
        value: existing&.fetch("value", 70)
      }
    end
  end

  def available_badges
    BadgeConfigStore.badges
  end

  def meta_condition_rows
    Array(@badge&.dig("conditions", "all")).reject do |condition|
      TRACKERS.value?(condition["key"])
    end
  end

  def meta_condition_types
    [
      ["Forest Explorations ≥", "explorations_at_least"],
      ["Flag True", "flag_true"],
      ["Badge Unlocked", "badge_unlocked"],
      ["Season Is", "season_is"],
      ["Item Held", "item_held"]
    ]
  end
end
