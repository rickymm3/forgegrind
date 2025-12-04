module Admin
  class EncounterBuilder
    attr_reader :entry, :params, :errors

    def self.blank_node
      {
        key: "",
        label: "",
        text: "",
        conclusion: false,
        outcome: "",
        status: "",
        options: []
      }
    end

  def self.blank_option
    {
      key: "",
      label: "",
      description: "",
      next_node: "",
      outcome: "",
      timer_seconds: "",
      success_chance: "",
      status: "",
      failure_next_node: "",
      failure_outcome: "",
      failure_status: "",
      requires_special_abilities: "",
      requires_special_ability_tags: ""
    }
  end

  def self.blank_association
    {
      world_keys: [],
      affix_keys: [],
      suffix_keys: []
    }
  end

  def self.blank_association
    {
      world_keys: [],
      affix_keys: [],
      suffix_keys: []
    }
  end

  def initialize(entry, params)
    @entry = entry
    @params = params || {}
    @errors = []
  end

  def save
    data = entry.data.deep_dup
    apply_basic_fields!(data)
    data["nodes"] = build_nodes
    data["associations"] = build_associations
    data["rewards"] = parse_rewards
    ExplorationEncounterStore.update!(slug: entry.slug, attributes: data)
    true
    rescue StandardError => e
      errors << e.message
      false
    end

    private

    def apply_basic_fields!(data)
      data["title"] = params[:title].to_s.presence if params.key?(:title)
      data["summary"] = params[:summary].to_s.presence if params.key?(:summary)
      data["weight_tier"] = params[:weight_tier].to_s.presence if params.key?(:weight_tier)
      data["tags"] = csv_to_array(params[:tags])
      data["requirement_tags"] = csv_to_array(params[:requirement_tags])
    end

    def build_nodes
      entries = {}
      node_list = collection_values(params[:nodes])
      node_list.each do |node|
        entry = node.is_a?(Hash) ? node : node.to_h
        key = entry["key"].to_s.strip
        next if key.blank?

        node_payload = {}
        %w[label text narrative].each do |attribute|
          value = entry[attribute]
          node_payload[attribute] = value.to_s.presence if value.present?
        end

        if truthy?(entry["conclusion"])
          node_payload["conclusion"] = true
        end

        %w[outcome status].each do |attribute|
          value = entry[attribute]
          node_payload[attribute] = value.to_s.presence if value.present?
        end

        options = build_options(entry["options"])
        node_payload["options"] = options if options.any?
        entries[key] = node_payload
      end
      entries
    end

    def build_options(options_param)
    collection_values(options_param).each_with_index.filter_map do |option_params, index|
        option_hash = option_params.is_a?(Hash) ? option_params : option_params.to_h
        key = option_hash["key"].to_s
        key = "option_#{index + 1}" if key.blank?

        payload = { "key" => key }
        %w[label description next_node outcome status failure_next_node failure_outcome failure_status].each do |attribute|
          value = option_hash[attribute]
          payload[attribute] = value.to_s.presence if value.present?
        end

        if option_hash["timer_seconds"].present?
          payload["timer_seconds"] = option_hash["timer_seconds"].to_i
        end

        if option_hash["success_chance"].present?
          payload["success_chance"] = option_hash["success_chance"].to_f
        end

        requires = {}
        abilities = csv_to_array(option_hash["requires_special_abilities"])
        tags = csv_to_array(option_hash["requires_special_ability_tags"])
        requires["special_abilities"] = abilities if abilities.any?
        requires["special_ability_tags"] = tags if tags.any?
        payload["requires"] = requires if requires.any?

        payload
    end
  end

  def build_associations
    associations = []
    collection_values(params[:associations]).each do |assoc|
      assoc_hash = assoc.is_a?(Hash) ? assoc : assoc.to_h
      worlds = array_param(assoc_hash["world_keys"])
      affixes = array_param(assoc_hash["affix_keys"])
      suffixes = array_param(assoc_hash["suffix_keys"])
      next if worlds.blank? && affixes.blank? && suffixes.blank?

      payload = {}
      payload["world_keys"] = worlds if worlds.any?
      payload["affix_keys"] = affixes if affixes.any?
      payload["suffix_keys"] = suffixes if suffixes.any?
      associations << payload
    end
    associations
  end

  def parse_rewards
      raw = params[:rewards_yaml].to_s
      return entry.data["rewards"] if raw.blank?

      YAML.safe_load(raw, permitted_classes: [Symbol], aliases: true) || {}
    rescue Psych::Exception => e
      raise StandardError, "Invalid rewards YAML: #{e.message}"
    end

    def csv_to_array(value)
      return [] unless value.present?
      value.to_s.split(",").map { |entry| entry.strip.presence }.compact
    end

  def truthy?(value)
    return false if value.nil?
    ActiveRecord::Type::Boolean.new.cast(value)
  end

  def array_param(value)
    return [] if value.nil?

    Array(value).map { |entry| entry.to_s.strip }.reject(&:blank?)
  end

  def collection_values(value)
    case value
      when ActionController::Parameters
        value.to_unsafe_h.values
      when Hash
        value.values
      else
        Array(value)
      end
    end
  end
end
