class ExplorationsController < ApplicationController
  include ExplorationsHelper
  RewardItem = Struct.new(:item, :quantity, keyword_init: true)

  before_action :authenticate_user!
  before_action :set_generated_exploration, only: %i[preview start reroll party_picker]

  def index
    load_exploration_sets
    @selected_generated = find_selected_generated(@generated_explorations)
    assign_rescout_state
    @slot_entries = build_slot_entries(@selected_generated)

    respond_to do |format|
      format.html
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "worlds-list",
          partial: "explorations/worlds_list",
          locals: {
            slot_entries: @slot_entries
          }
        )
      end
    end
  end

  def zone
    load_exploration_sets
    assign_rescout_state

    requested_id = params[:id] || params[:generated_id] || params[:generated_exploration_id]
    @selected_generated = if requested_id.present?
                            @generated_explorations.find do |generated|
                              generated.id == requested_id.to_i
                            end
                          end
    @selected_generated ||= find_selected_generated(@generated_explorations)

    unless @selected_generated
      redirect_to explorations_path, alert: "No expedition available." and return
    end

    context = detail_locals(@selected_generated)
    @user_exploration = context[:user_exploration]
    @requirement_progress = context[:requirement_progress]
    @requirement_groups = context[:requirement_groups]
    @equipped_pets = current_user.user_pets.equipped.includes(:learned_abilities, pet: :pet_types)
    @equipped_pet_ids = @equipped_pets.pluck(:id)
    @available_pets = load_available_pets({})
    @storage_pets = @available_pets.where.not(id: @equipped_pet_ids)
                                   .reorder(Arel.sql("user_pets.power DESC"))
    @selected_pet_ids = []
    @filters = {}
    @slot_entries = build_slot_entries(@selected_generated)
    @zone_state = inferred_zone_state(@user_exploration)
  end

  def show
    load_exploration_sets
    assign_rescout_state

    @generated_exploration = find_generated_for_show(params[:id])
    if @generated_exploration.nil?
      redirect_to explorations_path, alert: "Expedition not found." and return
    end

    redirect_to zone_explorations_path(id: @generated_exploration.id) and return

    context = detail_locals(@generated_exploration)
    @user_exploration = context[:user_exploration]
    @requirement_progress = context[:requirement_progress]
    @requirement_groups = context[:requirement_groups]
    @available_pets = load_available_pets({})
    @selected_pet_ids = []
    @filters = {}
    @selected_generated = @generated_exploration
    @slot_entries = build_slot_entries(@selected_generated)
  end

  def reroll
    slot_index = @generated_exploration.slot_index
    head :unprocessable_entity and return unless slot_index

    if current_user.user_explorations.where(generated_exploration: @generated_exploration, completed_at: nil).exists?
      respond_with_reroll_error("Expedition is currently underway.") and return
    end

    if @generated_exploration.slot_state_sym == :cooldown
      respond_with_reroll_error("This slot is cooling down.") and return
    end

    if @generated_exploration.reroll_cooldown_active?
      wait_text = helpers.distance_of_time_in_words(@generated_exploration.reroll_available_at)
      respond_with_reroll_error("Reroll available in #{wait_text}.") and return
    end

    reroll_ready_at = Time.current + ExplorationGenerator::RESCOUT_COOLDOWN

    @generated_exploration.destroy
    generator = ExplorationGenerator.new(current_user)
    generator.generate!(slot_index: slot_index, force: true)
    new_generated = current_user.generated_explorations.find_by(slot_index: slot_index)
    new_generated&.set_reroll_cooldown!(reroll_ready_at)
    new_generated&.set_slot_state!(:active)

    context = new_generated ? detail_locals(new_generated) : {}
    @user_exploration = context[:user_exploration]
    @requirement_progress = context[:requirement_progress]
    @requirement_groups = context[:requirement_groups]
    @equipped_pets = current_user.user_pets.equipped.includes(:learned_abilities, pet: :pet_types)
    @equipped_pet_ids = @equipped_pets.pluck(:id)
    @available_pets = load_available_pets({})
    @storage_pets = @available_pets.where.not(id: @equipped_pet_ids)
                                   .reorder(Arel.sql("user_pets.power DESC"))
    @selected_pet_ids = []
    @filters = {}
    @zone_state = inferred_zone_state(@user_exploration)

    load_exploration_sets
    assign_rescout_state
    @selected_generated = new_generated
    @slot_entries = build_slot_entries(new_generated)

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = "Expedition rerolled."
        streams = []
        streams << turbo_stream.update(
          "worlds-list",
          partial: "explorations/worlds_list",
          locals: {
            slot_entries: @slot_entries
          }
        )
        if new_generated
          streams << turbo_stream.update(
            "zone-card-container",
            partial: "explorations/zone_card_wrapper",
            locals: {
              generated_exploration: new_generated,
              user_exploration: @user_exploration,
              requirement_progress: @requirement_progress,
              requirement_groups: @requirement_groups,
              available_pets: @available_pets,
              selected_pet_ids: @selected_pet_ids,
              filters: @filters,
              state: @zone_state
            }
          )
          streams << turbo_stream.update(
            "zone-map-container",
            partial: "explorations/zone_card/map",
            locals: { generated: new_generated, user_exploration: @user_exploration }
          )
          streams << turbo_stream.update(
            "zone-descriptors",
            partial: "explorations/zone_card/descriptors",
            locals: { descriptors: exploration_descriptor_pills(new_generated) }
          )
          streams << turbo_stream.update(
            "zone-rescout-wrapper",
            partial: "explorations/zone_card/rescout",
            locals: { generated: new_generated,
                      user_exploration: @user_exploration }
          ) if view_context.lookup_context.exists?("explorations/zone_card/_rescout")
        end
        streams << turbo_stream.update(
          "flash_messages",
          partial: "shared/flash_messages"
        )
        render turbo_stream: streams and return
      end
      format.html do
        redirect_to(new_generated ? zone_explorations_path(id: new_generated.id) : explorations_path, notice: "Expedition rerolled.")
      end
    end
  end

  def scout
    slot_index = params[:slot_index].presence
    slot_index = slot_index.to_i if slot_index
    max_slots = ExplorationGenerator::DEFAULT_COUNT
    slot_index = nil unless slot_index.present? && slot_index.between?(1, max_slots)

    generator = ExplorationGenerator.new(current_user)
    generator.generate!(force: true, slot_index: slot_index)

    load_exploration_sets
    assign_rescout_state
    selected = if slot_index
                 @generated_explorations.find { |gen| gen.slot_index == slot_index } || find_selected_generated(@generated_explorations)
               else
                 find_selected_generated(@generated_explorations)
               end
    @slot_entries = build_slot_entries(selected)

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = "Your scouting party refreshed the expedition board."
        render turbo_stream: [
          turbo_stream.update(
            "worlds-list",
            partial: "explorations/worlds_list",
            locals: { slot_entries: @slot_entries }
          ),
          turbo_stream.update(
            "flash_messages",
            partial: "shared/flash_messages"
          )
        ]
      end
      format.html do
        redirect_to explorations_path, notice: "Your scouting party refreshed the expedition board."
      end
    end
  end

  def preview
    @filters = params.slice(:name, :pet_type_id).permit(:name, :pet_type_id)
    @selected_pet_ids = parse_selected_ids(params[:selected_pet_ids] || params[:user_pet_ids])
    @selected_pet_ids = @selected_pet_ids.first(4)
    @equipped_pets = current_user.user_pets.equipped.includes(:learned_abilities, pet: :pet_types)
    @equipped_pet_ids = @equipped_pets.pluck(:id)
    @available_pets = load_available_pets(@filters)
    @storage_pets = @available_pets.where.not(id: @equipped_pet_ids)
                                   .reorder(Arel.sql("user_pets.power DESC"))
    @selected_pets = current_user.user_pets.active.includes(:learned_abilities, pet: :pet_types).where(id: @selected_pet_ids)
    @progress = @generated_exploration.requirements_progress_for(@selected_pets)
    show_filters = params[:show_filters].nil? ? true : ActiveModel::Type::Boolean.new.cast(params[:show_filters])
    compact_layout = ActiveModel::Type::Boolean.new.cast(params[:compact_layout])

    respond_to do |format|
      format.turbo_stream do
        card_dom_id = view_context.dom_id(@generated_exploration, :detail)
        grouped = @progress.group_by { |req| req[:source] || 'base' }

        streams = []
        streams << turbo_stream.update(
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
            filters: @filters,
            show_filters: show_filters,
            compact_layout: compact_layout
          }
        )
        streams << turbo_stream.update("party-picker-panel", "")
        render turbo_stream: streams
      end
      format.html { redirect_to zone_explorations_path(id: @generated_exploration.id) }
    end
  end

  def party_picker
    role = params[:role].presence_in(%w[leader companion]) || "companion"
    if params[:cancel].present?
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("party-picker-panel", "")
        end
        format.html { redirect_to zone_explorations_path(id: @generated_exploration.id) }
      end
      return
    end

    @filters = params.slice(:name, :pet_type_id, :rarity_id).permit(:name, :pet_type_id, :rarity_id)
    @selected_pet_ids = parse_selected_ids(params[:selected_pet_ids]).first(4)

    active_ids = current_user.user_explorations.joins(:user_pets).where(completed_at: nil).pluck("user_pets.id")
    scope = current_user.user_pets.active.includes(:rarity, pet: :pet_types)
    scope = if role == "leader"
              scope.equipped
            else
              scope.where(active_slot: nil)
            end
    scope = scope.where.not(id: active_ids)
    scope = scope.where.not(id: @selected_pet_ids) if @selected_pet_ids.any?
    scope = scope.where("asleep_until IS NULL OR asleep_until <= ?", Time.current)
    scope = scope.where("user_pets.name ILIKE ?", "%#{@filters[:name]}%") if @filters[:name].present?
    scope = scope.joins(pet: :pet_types).where(pet_types: { id: @filters[:pet_type_id] }) if @filters[:pet_type_id].present?
    scope = scope.where(rarity_id: @filters[:rarity_id]) if @filters[:rarity_id].present?

    @role = role
    @pets = scope.order(Arel.sql("user_pets.power DESC"))

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "party-picker-panel",
          partial: "explorations/party_picker",
          locals: {
            generated_exploration: @generated_exploration,
            pets: @pets,
            role: @role,
            filters: @filters,
            selected_pet_ids: @selected_pet_ids
          }
        )
      end
      format.html { redirect_to zone_explorations_path(id: @generated_exploration.id) }
    end
  end

  def start
    selected_ids = parse_selected_ids(params[:user_pet_ids])
    if selected_ids.empty?
      flash[:alert] = "Please select at least one pet to explore."
      redirect_to zone_explorations_path(id: @generated_exploration.id) and return
    end

    if selected_ids.size > 4
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

    ordered_ids = parse_party_order(selected_ids, params[:party_order])
    primary_id = params[:primary_user_pet_id].presence&.to_i
    primary_id = ordered_ids.first if primary_id.blank? || !ordered_ids.include?(primary_id)

    primary_pet = @selected_pets.find { |pet| pet.id == primary_id }
    unless primary_pet
      head :unprocessable_entity and return
    end

    equipped_ids = current_user.user_pets.equipped.pluck(:id)
    unless equipped_ids.include?(primary_pet.id)
      flash[:alert] = "Leader must be one of your active pets."
      redirect_to zone_explorations_path(id: @generated_exploration.id) and return
    end

    companion_ids = ordered_ids - [primary_id]
    unless (companion_ids & equipped_ids).empty?
      flash[:alert] = "Companions must be chosen from storage pets."
      redirect_to zone_explorations_path(id: @generated_exploration.id) and return
    end

    begin
      ActiveRecord::Base.transaction do
        primary_pet.lock!
        primary_pet.spend_energy!(UserPet::EXPLORATION_ENERGY_COST, allow_debt: true)
        primary_pet.save!(validate: false)

        @user_exploration = current_user.user_explorations.create!(
          world: @generated_exploration.world,
          generated_exploration: @generated_exploration,
          started_at: Time.current,
          primary_user_pet: primary_pet
        )
        @user_exploration.user_pets << @selected_pets

        progress = @generated_exploration.requirements_progress_for(@selected_pets)
        fulfilled_requirement_ids = progress.select { |entry| entry[:fulfilled] }.map { |entry| entry[:id] }

        snapshot = build_party_snapshot(@selected_pets, ordered_ids, primary_pet, requirements: progress)
        ability_refs = snapshot[:members].map { |entry| entry[:special_ability_reference] }.compact
        ability_tags = snapshot[:members].flat_map { |entry| entry[:special_ability_tags] }.compact.uniq

        schedule = if @user_exploration.segment_definitions.blank?
                     [] # zero-checkpoint routes should not seed encounters
                   else
                     ExplorationEncounterCatalog.schedule_for(
                       world: @generated_exploration.world,
                       duration: @user_exploration.duration_seconds,
                       base_key: @generated_exploration.base_key,
                       prefix_key: @generated_exploration.prefix_key,
                       suffix_key: @generated_exploration.suffix_key,
                       ability_refs: ability_refs,
                       ability_tags: ability_tags,
                       requirements: progress,
                       fulfilled_ids: fulfilled_requirement_ids,
                       seed: @user_exploration.id,
                       segments: @user_exploration.segment_definitions
                     )
                   end

        @user_exploration.update!(
          party_snapshot: snapshot,
          encounter_schedule: schedule,
          encounters_seeded_at: Time.current
        )
        initialize_segment_progress!(@user_exploration)
        @user_exploration.reload
        @generated_exploration.mark_consumed!
      end
    rescue UserPet::PetSleepingError, UserPet::NotEnoughEnergyError => e
      flash[:alert] = e.message
      redirect_to zone_explorations_path(id: @generated_exploration.id) and return
    end

    load_exploration_sets
    assign_rescout_state
    @slot_entries = build_slot_entries(@user_exploration.generated_exploration)

    respond_to do |format|
      format.turbo_stream do
        render "explorations/start"
      end
      format.html { redirect_to zone_explorations_path(id: @generated_exploration.id) }
    end
  end

  private

  def set_generated_exploration
    @generated_exploration = current_user.generated_explorations.available.find(params[:id])
  end

  def load_exploration_sets
    @active_explorations = current_user.user_explorations.includes(generated_exploration: { world: :pet_types }).where(completed_at: nil)
    @active_explorations.each do |exploration|
      exploration.reload if exploration.sync_segment_timers!
    end
    @active_explorations.each do |exploration|
      exploration.auto_trigger_due_encounter!
    end

    max_slots = ExplorationGenerator::DEFAULT_COUNT

    available_generated = current_user.generated_explorations
                                      .available
                                      .includes(world: :pet_types)
                                      .where(slot_index: 1..max_slots)
                                      .order(:slot_index, :created_at)
                                      .to_a
    available_generated.each(&:clear_reroll_cooldown_if_elapsed!)

    existing_by_slot = available_generated.index_by(&:slot_index)
    active_by_slot = @active_explorations.each_with_object({}) do |exploration, memo|
      slot_index = exploration.generated_exploration&.slot_index
      memo[slot_index] = true if slot_index
    end

    slot_range = 1..max_slots

    slot_range.each do |slot|
      generated = existing_by_slot[slot]
      next unless generated&.slot_state_sym == :cooldown
      next if generated.cooldown_active?

      generated.destroy
      existing_by_slot.delete(slot)
    end

    available_generated.reject! { |gen| gen.slot_state_sym == :cooldown && !gen.cooldown_active? }

    if current_user.last_scouted_at.nil? && available_generated.empty?
      ExplorationGenerator.new(current_user).generate!(force: true)
      available_generated = current_user.generated_explorations
                                        .available
                                        .includes(world: :pet_types)
                                        .where(slot_index: 1..max_slots)
                                        .order(:slot_index, :created_at)
                                        .to_a
      available_generated.each(&:clear_reroll_cooldown_if_elapsed!)
      existing_by_slot = available_generated.index_by(&:slot_index)
    end

    @generated_explorations = available_generated.dup
    @active_explorations.each do |exploration|
      generated = exploration.generated_exploration
      next unless generated
      @generated_explorations << generated unless @generated_explorations.include?(generated)
    end
    @generated_explorations.uniq!

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

  def inferred_zone_state(user_exploration)
    return :selection unless user_exploration

    if user_exploration.active_encounter? || user_exploration.checkpoint_segment_entry.present?
      :checkpoint
    elsif user_exploration.complete?
      :ready
    else
      :active
    end
  end

  def build_slot_entries(selected_generated)
    Explorations::SlotLayoutBuilder.build(
      max_slots: ExplorationGenerator::DEFAULT_COUNT,
      generated_explorations: @generated_explorations,
      active_explorations: @active_explorations,
      requirement_map: @requirement_map,
      selected_generated: selected_generated
    )
  end

  def assign_rescout_state
    remaining = ExplorationGenerator.cooldown_remaining_for(current_user)
    @rescout_cooldown_remaining = remaining
    if remaining.positive?
      @rescout_available_at = Time.current + remaining.seconds
      @rescout_wait_human = view_context.distance_of_time_in_words(Time.current, @rescout_available_at)
    else
      @rescout_available_at = Time.current
      @rescout_wait_human = nil
    end
  end

  def respond_with_reroll_error(message)
    respond_to do |format|
      format.turbo_stream do
        flash.now[:alert] = message
        render turbo_stream: turbo_stream.update(
          "flash_messages",
          partial: "shared/flash_messages"
        )
      end
      format.html do
        redirect_back fallback_location: explorations_path, alert: message
      end
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
    pets
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

  def find_generated_for_show(id)
    current_user.generated_explorations.includes(world: :pet_types).find_by(id: id)
  end

  def detail_locals(generated)
    if generated.nil?
      active = @active_explorations&.first
      if active
        active.reload if active.sync_segment_timers!
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
      user_exploration.reload if user_exploration.sync_segment_timers!
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

  def parse_party_order(selected_ids, raw_order)
    order = parse_selected_ids(raw_order)
    return selected_ids if order.blank?

    ordered = order.select { |id| selected_ids.include?(id) }
    remaining = selected_ids - ordered
    ordered + remaining
  end

  def build_party_snapshot(pets, ordered_ids, primary_pet, requirements: [])
    pet_map = pets.index_by(&:id)
    members = ordered_ids.map do |id|
      pet = pet_map[id]
      next unless pet

      {
        user_pet_id: pet.id,
        pet_id: pet.pet.id,
        display_name: pet.name.presence || pet.pet.name,
        species: pet.pet.name,
        rarity: pet.rarity.name,
        power: pet.pet.power,
        special_ability_reference: pet.special_ability_reference,
        special_ability_name: pet.special_ability_name,
        special_ability_tags: pet.special_ability_tags,
        pet_types: pet.pet.pet_types.map(&:name)
      }
    end.compact

    {
      ordered_user_pet_ids: members.map { |member| member[:user_pet_id] },
      primary_user_pet_id: primary_pet.id,
      members: members,
      requirements: requirements
    }
  end

  def initialize_segment_progress!(user_exploration)
    definitions = user_exploration.segment_definitions
    return if definitions.blank?

    started_at = user_exploration.started_at || Time.current
    progress_entries = definitions.each_with_index.map do |definition, index|
      entry = {
        index: index,
        key: definition[:key],
        label: definition[:label],
        duration_seconds: definition[:duration_seconds],
        checkpoint_offset_seconds: definition[:checkpoint_offset_seconds],
        status: index.zero? ? 'active' : 'upcoming',
        reached_at: index.zero? ? started_at : nil,
        completed_at: nil
      }
      entry[:allow_encounters] = definition.key?(:allow_encounters) ? definition[:allow_encounters] : true
      entry[:encounters_enabled] = definition.key?(:encounters_enabled) ? definition[:encounters_enabled] : true
      entry[:source] = definition[:source] if definition.key?(:source)

      if defined?(ExplorationGenerator::SEGMENT_OPTIONAL_KEYS)
        ExplorationGenerator::SEGMENT_OPTIONAL_KEYS.each do |key|
          next if %i[allow_encounters encounters_enabled].include?(key)

          value = definition[key]
          next if value.nil?

          entry[key] =
            case key
            when :encounter_tags, :encounter_slugs, :requirement_tags
              Array(value).map(&:to_s).reject(&:blank?)
            else
              value
            end
        end
      end

      entry
    end

    user_exploration.update!(
      segment_progress: progress_entries.map(&:stringify_keys),
      current_segment_index: 0,
      segment_started_at: started_at
    )
  end

  def cooldown_remaining_for(user)
    0
  end
end
