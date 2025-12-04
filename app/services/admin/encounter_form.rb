module Admin
  class EncounterForm
    class << self
      def from_entry(entry)
        data = entry.data.with_indifferent_access
        {
          slug: entry.slug,
          title: data[:title],
          summary: data[:summary],
          weight_tier: data[:weight_tier],
          tags: Array(data[:tags]).join(", "),
          requirement_tags: Array(data[:requirement_tags]).join(", "),
          rewards_yaml: format_yaml(data[:rewards]),
          nodes: build_nodes_from_hash(data[:nodes]),
          associations: build_associations_from_hash(data[:associations])
        }
      end

      def from_params(entry, params)
        {
          slug: entry.slug,
          title: params[:title],
          summary: params[:summary],
          weight_tier: params[:weight_tier],
          tags: params[:tags],
          requirement_tags: params[:requirement_tags],
          rewards_yaml: params[:rewards_yaml],
          nodes: build_nodes_from_params(params[:nodes]),
          associations: build_associations_from_params(params[:associations])
        }
      end

      private

      def format_yaml(payload)
        return "" if payload.blank?
        payload.to_yaml(line_width: -1)
      end

      def build_nodes_from_hash(nodes_hash)
        return [] unless nodes_hash.is_a?(Hash)

        nodes_hash.map do |key, definition|
          definition = definition.with_indifferent_access
          {
            key: key,
            label: definition[:label],
            text: definition[:text],
            conclusion: ActiveRecord::Type::Boolean.new.cast(definition[:conclusion]),
            outcome: definition[:outcome],
            status: definition[:status],
            options: build_options_from_hash(definition[:options])
          }
        end
      end

      def build_options_from_hash(options_hash)
        Array(options_hash).map do |option|
          option = option.with_indifferent_access
          requires = option[:requires] || {}
          {
            key: option[:key],
            label: option[:label],
            description: option[:description],
            next_node: option[:next_node],
            outcome: option[:outcome],
            timer_seconds: option[:timer_seconds],
            success_chance: option[:success_chance],
            status: option[:status],
            failure_next_node: option[:failure_next_node],
            failure_outcome: option[:failure_outcome],
            failure_status: option[:failure_status],
            requires_special_abilities: Array(requires[:special_abilities]).join(", "),
            requires_special_ability_tags: Array(requires[:special_ability_tags]).join(", ")
          }
        end
      end

      def build_nodes_from_params(nodes_params)
        collection_values(nodes_params).map do |node|
          node = node.is_a?(Hash) ? node : node.to_h
          {
            key: node["key"],
            label: node["label"],
            text: node["text"],
            conclusion: ActiveRecord::Type::Boolean.new.cast(node["conclusion"]),
            outcome: node["outcome"],
            status: node["status"],
            options: build_options_from_params(node["options"])
          }
        end
      end

      def build_options_from_params(options_params)
        collection_values(options_params).map do |option|
          option = option.is_a?(Hash) ? option : option.to_h
          {
            key: option["key"],
            label: option["label"],
            description: option["description"],
            next_node: option["next_node"],
            outcome: option["outcome"],
            timer_seconds: option["timer_seconds"],
            success_chance: option["success_chance"],
            status: option["status"],
            failure_next_node: option["failure_next_node"],
            failure_outcome: option["failure_outcome"],
            failure_status: option["failure_status"],
            requires_special_abilities: option["requires_special_abilities"],
            requires_special_ability_tags: option["requires_special_ability_tags"]
          }
        end
      end

      def build_associations_from_hash(entries)
        Array(entries).map do |assoc|
          assoc = assoc.with_indifferent_access
          {
            world_keys: Array(assoc[:world_keys]),
            affix_keys: Array(assoc[:affix_keys]),
            suffix_keys: Array(assoc[:suffix_keys])
          }
        end
      end

      def build_associations_from_params(entries)
        collection_values(entries).map do |assoc|
          assoc = assoc.is_a?(Hash) ? assoc : assoc.to_h
          {
            world_keys: Array(assoc["world_keys"]).reject(&:blank?),
            affix_keys: Array(assoc["affix_keys"]).reject(&:blank?),
            suffix_keys: Array(assoc["suffix_keys"]).reject(&:blank?)
          }
        end
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
end
