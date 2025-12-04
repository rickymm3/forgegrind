module Admin
  class ExplorationBasesController < BaseController
    before_action :set_store
    before_action :set_entry, only: [:edit, :update]

    def index
      @bases = @store.all_entries
    end

    def edit; end

    def update
      attributes = build_attributes(@entry.data, base_params)
      @store.update!(key: @entry.key, attributes: attributes)
      redirect_to admin_exploration_bases_path, notice: "#{@entry.key} updated."
    rescue Psych::SyntaxError => e
      redirect_to edit_admin_exploration_basis_path(@entry.key), alert: "Invalid YAML: #{e.message}"
    end

    private

    def set_store
      @store = ExplorationConfigCollectionStore.new(
        path: Rails.root.join("config", "explorations", "bases.yml"),
        root_key: :bases
      )
    end

    def set_entry
      @entry = @store.find(params[:id])
      redirect_to admin_exploration_bases_path, alert: "Base not found." unless @entry
    end

    def base_params
      params.require(:base).permit(
        :label,
        :world_name,
        :world_key,
        :tier,
        :player_level_min,
        :default_duration,
        :flavor,
        :world_tags_text,
        :checkpoint_labels_text,
        :requirements_yaml,
        :rewards_yaml
      )
    end

    def build_attributes(original, params)
      updated = deep_dup(original)
      updated["label"] = params[:label]
      updated["world_name"] = params[:world_name]
      updated["world_key"] = params[:world_key]
      updated["tier"] = params[:tier].to_i if params[:tier]
      updated["player_level_min"] = params[:player_level_min].to_i if params[:player_level_min]
      updated["default_duration"] = params[:default_duration].to_i if params[:default_duration]
      updated["flavor"] = params[:flavor]
      updated["world_tags"] = normalize_list(params[:world_tags_text]) if params.key?(:world_tags_text)
      updated["checkpoint_labels"] = normalize_list(params[:checkpoint_labels_text]) if params.key?(:checkpoint_labels_text)
      updated["requirements"] = parse_yaml(params[:requirements_yaml], default: []) if params.key?(:requirements_yaml)
      updated["rewards"] = parse_yaml(params[:rewards_yaml], default: {}) if params.key?(:rewards_yaml)
      updated
    end

    def normalize_list(text)
      return [] unless text

      text.to_s.split(/\r?\n|,/).map(&:strip).reject(&:blank?)
    end

    def parse_yaml(text, default:)
      return default if text.blank?

      YAML.safe_load(text, permitted_classes: [Symbol], aliases: true) || default
    end

    def deep_dup(object)
      case object
      when Hash
        object.each_with_object({}) { |(k, v), memo| memo[k] = deep_dup(v) }
      when Array
        object.map { |v| deep_dup(v) }
      else
        object.dup rescue object
      end
    end
  end
end
