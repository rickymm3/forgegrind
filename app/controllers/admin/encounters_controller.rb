module Admin
  class EncountersController < BaseController
    before_action :load_entries, only: :index
    before_action :set_encounter, only: [:edit, :update]
    before_action :load_association_options, only: [:edit, :update]

    def index; end

    def edit
      @form_data = Admin::EncounterForm.from_entry(@encounter)
    end

    def update
      builder = Admin::EncounterBuilder.new(@encounter, encounter_params.to_h)
      if builder.save
        redirect_to admin_encounters_path, notice: "Encounter #{@encounter.slug} updated."
      else
        flash.now[:alert] = builder.errors.join(", ")
        @form_data = Admin::EncounterForm.from_params(@encounter, encounter_params)
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def load_entries
      @encounters = ExplorationEncounterStore.all_entries
    end

    def set_encounter
      @encounter = ExplorationEncounterStore.find(params[:slug])
      return if @encounter

      redirect_to admin_encounters_path, alert: "Encounter not found."
    end

    def encounter_params
      params.require(:encounter).permit(
        :title,
        :summary,
        :weight_tier,
        :tags,
        :requirement_tags,
        :rewards_yaml,
        nodes: [
          :key,
          :label,
          :text,
          :conclusion,
          :outcome,
          :status,
          options: [
            :key,
            :label,
            :description,
            :next_node,
            :outcome,
            :timer_seconds,
            :success_chance,
            :status,
            :failure_next_node,
            :failure_outcome,
            :failure_status,
            :requires_special_abilities,
            :requires_special_ability_tags
          ]
        ],
        associations: [
          { world_keys: [], affix_keys: [], suffix_keys: [] }
        ]
      )
    end

    def load_association_options
      @world_options = load_options_from_store(
        path: Rails.root.join("config", "explorations", "bases.yml"),
        root_key: :bases,
        label_key: :label
      )
      @affix_options = load_options_from_store(
        path: Rails.root.join("config", "explorations", "affixes.yml"),
        root_key: :affixes,
        label_key: :label
      )
      @suffix_options = load_options_from_store(
        path: Rails.root.join("config", "explorations", "suffixes.yml"),
        root_key: :suffixes,
        label_key: :label
      )
    end

    def load_options_from_store(path:, root_key:, label_key:)
      store = ExplorationConfigCollectionStore.new(path: path, root_key: root_key)
      store.all_entries.map do |entry|
        data = entry.data.with_indifferent_access
        label = data[label_key].presence || entry.key.to_s.humanize
        [label, entry.key]
      end.sort_by { |label, _| label }
    end
  end
end
