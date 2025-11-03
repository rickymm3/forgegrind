class PetSpecialAbilityCatalog
  ABILITIES_CONFIG_PATH = Rails.root.join("config", "special_abilities.yml")
  PET_MAPPING_PATH      = Rails.root.join("config", "pet_special_abilities.yml")

  class << self
    def ability_definitions
      @ability_definitions ||= load_yaml(ABILITIES_CONFIG_PATH)
    end

    def pet_mapping
      @pet_mapping ||= begin
        raw = load_yaml(PET_MAPPING_PATH)
        raw.each_with_object({}) do |(pet_name, ability_reference), memo|
          next if pet_name.blank? || ability_reference.blank?
          memo[pet_name.to_s.downcase] = ability_reference.to_s
        end
      end
    end

    def default_reference_for(pet_name)
      return nil if pet_name.blank?
      pet_mapping[pet_name.to_s.downcase]
    end

    def sync_definitions!
      definitions = ability_definitions
      return {} if definitions.blank?

      definitions.each_with_object({}) do |(reference, attrs), memo|
        attrs ||= {}
        ability = SpecialAbility.find_or_initialize_by(reference: reference.to_s)
        ability.name           = fetch_attr(attrs, :name, reference.to_s.humanize)
        ability.tagline        = fetch_attr(attrs, :tagline)
        ability.description    = fetch_attr(attrs, :description)
        ability.encounter_tags = Array(fetch_attr(attrs, :encounter_tags)).map(&:to_s)
        ability.metadata       = fetch_attr(attrs, :metadata) || {}
        ability.save!
        memo[reference.to_s] = ability
      end
    end

    def backfill_pets!
      mapping = pet_mapping
      return if mapping.blank?

      abilities = SpecialAbility.where(reference: mapping.values).index_by(&:reference)

      Pet.find_each do |pet|
        next if pet.special_ability_id.present?

        ref = default_reference_for(pet.name)
        next if ref.blank?

        ability = abilities[ref] ||= SpecialAbility.find_by(reference: ref)
        next unless ability

        Pet.where(id: pet.id).update_all(
          special_ability_id: ability.id,
          updated_at: Time.current
        )
      end
    end

    def reload!
      @ability_definitions = nil
      @pet_mapping = nil
    end

    private

    def load_yaml(path)
      return {} unless path.exist?
      YAML.load_file(path) || {}
    rescue Psych::SyntaxError => e
      Rails.logger.error("Failed to load #{path}: #{e.message}")
      {}
    end

    def fetch_attr(hash, key, default = nil)
      hash[key.to_s] || hash[key.to_sym] || default
    end
  end
end
