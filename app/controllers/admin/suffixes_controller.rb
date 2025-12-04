module Admin
  class SuffixesController < BaseController
    before_action :set_store
    before_action :set_entry, only: [:edit, :update]

    def index
      @suffixes = @store.all_entries
    end

    def edit; end

    def update
      attributes = build_attributes(@entry.data, suffix_params)
      @store.update!(key: @entry.key, attributes: attributes)
      redirect_to admin_suffixes_path, notice: "#{@entry.key} updated."
    rescue Psych::SyntaxError => e
      redirect_to edit_admin_suffix_path(@entry.key), alert: "Invalid YAML: #{e.message}"
    end

    private

    def set_store
      @store = ExplorationConfigCollectionStore.new(
        path: Rails.root.join("config", "explorations", "suffixes.yml"),
        root_key: :suffixes
      )
    end

    def set_entry
      @entry = @store.find(params[:id])
      redirect_to admin_suffixes_path, alert: "Suffix not found." unless @entry
    end

    def suffix_params
      params.require(:suffix).permit(
        :label,
        :rarity,
        :weight,
        :player_level_min,
        :flavor,
        :applies_to_text,
        :duration_bonus,
        :requirements_yaml,
        :reward_modifiers_yaml,
        :checkpoint_labels_text
      )
    end

    def build_attributes(original, params)
      updated = deep_dup(original)
      updated["label"] = params[:label]
      updated["rarity"] = params[:rarity]
      updated["weight"] = params[:weight].to_i if params[:weight]
      updated["player_level_min"] = params[:player_level_min].to_i if params[:player_level_min]
      updated["flavor"] = params[:flavor] if params.key?(:flavor)
      updated["applies_to"] = normalize_list(params[:applies_to_text]) if params.key?(:applies_to_text)
      updated["duration"] ||= {}
      updated["duration"]["bonus"] = params[:duration_bonus].to_i if params[:duration_bonus]
      updated["requirements"] = parse_yaml(params[:requirements_yaml], default: []) if params.key?(:requirements_yaml)
      updated["reward_modifiers"] = parse_yaml(params[:reward_modifiers_yaml], default: {}) if params.key?(:reward_modifiers_yaml)
      updated["checkpoint_labels"] = normalize_list(params[:checkpoint_labels_text]) if params.key?(:checkpoint_labels_text)
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
