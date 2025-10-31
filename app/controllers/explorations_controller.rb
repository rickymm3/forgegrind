class ExplorationsController < ApplicationController
  RewardItem = Struct.new(:item, :quantity, keyword_init: true)
  before_action :set_generated_exploration, only: %i[preview start]

  helper_method :scout_button_options

  def index
    load_exploration_sets
    @selected_generated = find_selected_generated(@generated_explorations)
    assign_rescout_state

    if turbo_frame_request? && params[:generated_id].present?
      render partial: "explorations/detail_panel",
             locals: detail_locals(@selected_generated),
             layout: false
      return
    end
  end

  def scout
    generator = ExplorationGenerator.new(current_user)

    begin
      generator.generate!
    rescue ExplorationGenerator::CooldownNotElapsedError => error
      load_exploration_sets
      assign_rescout_state

      remaining = error.remaining_seconds
      wait_human = @rescout_wait_human || helpers.distance_of_time_in_words(Time.current, Time.current + remaining)
      message = "Your scouting party needs #{wait_human} to rest."
      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = message
          streams = []
          render_scout_button_streams(streams)
          streams << turbo_stream.update(
            "flash_messages",
            partial: "shared/flash_messages"
          )
          render turbo_stream: streams
        end
        format.html { redirect_to explorations_path, alert: message }
      end
      return
    end

    load_exploration_sets
    assign_rescout_state

    respond_to do |format|
      format.turbo_stream do
        selected = find_selected_generated(@generated_explorations)
        streams = []
        streams << turbo_stream.update(
          "worlds-list",
          partial: "explorations/worlds_list",
          locals: {
            generated_explorations: @generated_explorations,
            active_explorations: @active_explorations,
            requirement_map: @requirement_map,
            selected_generated: selected
          }
        )
        streams << turbo_stream.update(
          "exploration_detail",
          partial: "explorations/detail_panel",
          locals: detail_locals(selected)
        )
        render_scout_button_streams(streams)

        wait_text = @rescout_wait_human || helpers.distance_of_time_in_words(Time.current, Time.current + ExplorationGenerator::RESCOUT_COOLDOWN)
        flash.now[:notice] = if @generated_explorations.any?
                               "Your scouting party discovered new expeditions. Next scouts will be ready in #{wait_text}."
                             else
                               "All expeditions are currently underway. Your scouting party will be ready again in #{wait_text}."
                             end
        streams << turbo_stream.update(
          "flash_messages",
          partial: "shared/flash_messages"
        )

        render turbo_stream: streams
      end
      format.html do
        wait_text = @rescout_wait_human || helpers.distance_of_time_in_words(Time.current, Time.current + ExplorationGenerator::RESCOUT_COOLDOWN)
        notice = if @generated_explorations.any?
                   "Your scouting party discovered new expeditions."
                 else
                   "All expeditions are currently underway."
                 end
        notice = "#{notice} Next scouts will be ready in #{wait_text}."
        redirect_to explorations_path, notice: notice
      end
    end
  end

  def preview
    @filters = params.slice(:name, :pet_type_id).permit(:name, :pet_type_id)
    @selected_pet_ids = parse_selected_ids(params[:selected_pet_ids] || params[:user_pet_ids])
    @available_pets = load_available_pets(@filters)
    @selected_pets = current_user.user_pets.active.includes(:learned_abilities, pet: :pet_types).where(id: @selected_pet_ids)
    @progress = @generated_exploration.requirements_progress_for(@selected_pets)

    respond_to do |format|
      format.turbo_stream do
        card_dom_id = view_context.dom_id(@generated_exploration, :detail)
        grouped = @progress.group_by { |req| req[:source] || 'base' }

        render turbo_stream: turbo_stream.update(
          card_dom_id,
          partial: "explorations/zone_card",
          locals: {
            generated_exploration: @generated_exploration,
            state: :selection,
            user_exploration: nil,
            available_pets: @available_pets,
            selected_pet_ids: @selected_pet_ids,
            requirement_progress: @progress,
            requirement_groups: grouped,
            filters: @filters
          }
        )
      end
      format.html { redirect_to explorations_path(generated_id: @generated_exploration.id) }
    end
  end

  def start
    selected_ids = parse_selected_ids(params[:user_pet_ids])
    if selected_ids.empty?
      flash[:alert] = "Please select at least one pet to explore."
      redirect_to explorations_path(generated_id: @generated_exploration.id) and return
    end

    if selected_ids.size > 3
      head :unprocessable_entity and return
    end

    active_pet_ids = current_user.user_explorations
                                 .joins(:user_pets)
                                 .where(completed_at: nil)
                                 .pluck('user_pets.id')
    if (selected_ids & active_pet_ids).any?
      head :unprocessable_entity and return
    end

    @selected_pets = current_user.user_pets.active.includes(:learned_abilities, pet: :pet_types).where(id: selected_ids)
    if @selected_pets.blank?
      head :unprocessable_entity and return
    end
    if @selected_pets.size != selected_ids.size
      head :unprocessable_entity and return
    end

    @user_exploration = current_user.user_explorations.create!(
      world: @generated_exploration.world,
      generated_exploration: @generated_exploration,
      started_at: Time.current
    )
    @user_exploration.user_pets << @selected_pets
    @generated_exploration.mark_consumed!

    load_exploration_sets

    respond_to do |format|
      format.turbo_stream do
        render "explorations/start"
      end
      format.html { redirect_to explorations_path(generated_id: @generated_exploration.id) }
    end
  end

  private

  def set_generated_exploration
    @generated_exploration = current_user.generated_explorations.available.find(params[:id])
  end

  def load_exploration_sets
    @active_explorations = current_user.user_explorations.includes(generated_exploration: { world: :pet_types }).where(completed_at: nil)
    max_slots = ExplorationGenerator::DEFAULT_COUNT
    available_slots = [max_slots - @active_explorations.size, 0].max

    generated_scope = current_user.generated_explorations.available.includes(world: :pet_types).order(:created_at)
    generated_scope = generated_scope.limit(available_slots) if available_slots.positive?
    @generated_explorations = available_slots.positive? ? generated_scope.to_a : []

    @requirement_map = build_requirement_map(@generated_explorations)
    @active_explorations.each do |user_exploration|
      generated = user_exploration.generated_exploration
      next unless generated

      progress = generated.requirements_progress_for(user_exploration.user_pets)
      @requirement_map[generated.id] = {
        progress: progress,
        grouped: progress.group_by { |entry| entry[:source] || 'base' }
      }
    end
  end

  def assign_rescout_state
    @rescout_cooldown_remaining = cooldown_remaining_for(current_user)
    if @rescout_cooldown_remaining.positive?
      @rescout_available_at = Time.current + @rescout_cooldown_remaining
      @rescout_wait_human = helpers.distance_of_time_in_words(Time.current, @rescout_available_at)
    else
      @rescout_wait_human = nil
      @rescout_available_at = nil
    end
  end

  def load_available_pets(filters)
    pets = current_user.user_pets.active.includes(:learned_abilities, pet: :pet_types)
    if filters[:name].present?
      pets = pets.where('user_pets.name ILIKE ?', "%#{filters[:name]}%")
    end
    if filters[:pet_type_id].present?
      pets = pets.joins(pet: :pet_types).where(pet_types: { id: filters[:pet_type_id] })
    end
    pets.order(power: :desc).distinct
  end

  def find_selected_generated(generated_list)
    if params[:generated_id].present?
      target_id = params[:generated_id].to_i
      generated_match = generated_list.find { |gen| gen.id == target_id }
      return generated_match if generated_match

      active_match = @active_explorations.find { |exploration| exploration.generated_exploration_id == target_id }&.generated_exploration
      return active_match if active_match
    end

    generated_list.first || @active_explorations&.first&.generated_exploration
  end

  def build_requirement_map(generated_list, selected_pet_ids: [])
    selected_pets = current_user.user_pets.active.includes(:learned_abilities, pet: :pet_types).where(id: selected_pet_ids)
    generated_list.each_with_object({}) do |generated, memo|
      progress = generated.requirements_progress_for(selected_pets)
      memo[generated.id] = {
        progress: progress,
        grouped: progress.group_by { |req| req[:source] || 'base' }
      }
    end
  end

  def detail_locals(generated)
    if generated.nil?
      active = @active_explorations&.first
      if active
        progress = active.generated_exploration&.requirements_progress_for(active.user_pets) || []
        return {
          generated_exploration: active.generated_exploration || GeneratedExploration.new(world: active.world, name: active.world.name, duration_seconds: active.duration_seconds, requirements: []),
          requirement_progress: progress,
          requirement_groups: progress.group_by { |entry| entry[:source] || 'base' },
          user_exploration: active
        }
      else
        return { generated_exploration: nil }
      end
    end

    user_exploration = current_user.user_explorations.includes(:user_pets, generated_exploration: { world: :pet_types }).find_by(generated_exploration: generated, completed_at: nil)

    if user_exploration
      progress = generated.requirements_progress_for(user_exploration.user_pets)
      grouped = progress.group_by { |entry| entry[:source] || 'base' }
      return {
        generated_exploration: generated,
        requirement_progress: progress,
        requirement_groups: grouped,
        user_exploration: user_exploration
      }
    end

    progress_entry = build_requirement_map([generated])
    entry = progress_entry[generated.id] || { progress: [], grouped: {} }
    {
      generated_exploration: generated,
      requirement_progress: entry[:progress],
      requirement_groups: entry[:grouped],
      user_exploration: nil
    }
  end

  def parse_selected_ids(value)
    return [] if value.blank?

    if value.is_a?(String)
      value.split(',').map(&:to_i).uniq
    else
      Array(value).map(&:to_i).uniq
    end
  end

  def cooldown_remaining_for(user)
    ExplorationGenerator.cooldown_remaining_for(user)
  end

  SCOUT_BUTTON_VARIANTS = {
    primary: {
      button_id: "scout_primary_button",
      label: "Scout for Expeditions",
      button_class: "inline-flex items-center gap-2 rounded-lg bg-indigo-600 px-4 py-2 text-sm font-semibold text-white transition hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-400 disabled:opacity-60 disabled:cursor-not-allowed",
      show_wait_text: true,
      info_class: "text-xs text-slate-500 mt-1"
    }.freeze,
    sidebar: {
      button_id: "rescout_sidebar_button",
      label: "Rescout",
      button_class: "text-xs font-semibold text-indigo-600 hover:text-indigo-700 disabled:text-slate-400 disabled:cursor-not-allowed",
      form_class: "inline",
      show_wait_text: true,
      info_class: "mt-1 text-[11px] text-slate-400 text-right"
    }.freeze,
    secondary: {
      button_id: "scout_secondary_button",
      label: "Scout for new expeditions",
      button_class: "self-start inline-flex items-center gap-2 rounded-lg bg-indigo-600 px-4 py-2 text-sm font-semibold text-white transition hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-400 disabled:opacity-60 disabled:cursor-not-allowed",
      show_wait_text: true,
      info_class: "text-xs text-slate-500 mt-1"
    }.freeze,
    empty_state: {
      button_id: "scout_empty_state_button",
      label: "Scout for Expeditions",
      button_class: "inline-flex items-center gap-2 rounded-lg bg-indigo-600 px-4 py-2 text-sm font-semibold text-white transition hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-400 disabled:opacity-60 disabled:cursor-not-allowed",
      show_wait_text: true,
      info_class: "text-xs text-slate-400 mt-2"
    }.freeze
  }.freeze

  def scout_button_options(variant)
    SCOUT_BUTTON_VARIANTS.fetch(variant)
  end

  def render_scout_button_streams(streams)
    button_variants_for_render.each do |variant|
      options = scout_button_options(variant)
      streams << turbo_stream.update(
        options[:button_id],
        partial: "explorations/scout_button",
        locals: options.merge(
          disabled: @rescout_cooldown_remaining.to_i.positive?,
          wait_human: @rescout_wait_human,
          unlock_at: @rescout_available_at
        )
      )
    end
  end

  def button_variants_for_render
    variants = []
    if @generated_explorations.any?
      variants << :sidebar
    else
      variants << :primary
      if @active_explorations.any?
        variants << :secondary
      else
        variants << :empty_state
      end
    end
    variants
  end
end
