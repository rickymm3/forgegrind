class TmBoxOpener
  Result = Struct.new(:granted_skill, :user_pet_skill, :errors, keyword_init: true)

  def initialize(user:, user_item:)
    @user = user
    @user_item = user_item
    @config = load_config
  end

  def call
    return Result.new(errors: ["Invalid TM box"]) unless tm_box_config
    return Result.new(errors: ["No boxes left"]) if @user_item.quantity.to_i <= 0

    ActiveRecord::Base.transaction do
      skill_def = tm_box_config[:skills].sample
      pet_skill = find_or_create_skill(skill_def)
      ups = @user.user_pet_skills.find_or_initialize_by(pet_skill: pet_skill, tier: pet_skill.tier)
      ups.quantity = ups.quantity.to_i + 1
      ups.save!

      @user_item.update!(quantity: @user_item.quantity.to_i - 1)

      return Result.new(granted_skill: pet_skill, user_pet_skill: ups, errors: [])
    end
  rescue StandardError => e
    Result.new(errors: [e.message])
  end

  private

  def tm_box_config
    @tm_box_config ||= @config[@user_item.item.item_type.to_s]
  end

  def load_config
    path = Rails.root.join("config", "tm_boxes.yml")
    return {} unless path.exist?
    raw = YAML.load_file(path)
    raw.each_with_object({}) do |(box_type, data), memo|
      skills = Array(data["skills"]).map { |s| s.deep_symbolize_keys }
      memo[box_type] = { skills: skills }
    end
  end

  def find_or_create_skill(defn)
    PetSkill.find_or_create_by!(key: defn[:key]) do |skill|
      skill.name = defn[:name]
      skill.rarity = defn[:rarity] || "common"
      skill.description = defn[:description]
      skill.family = defn[:family] || defn[:key].split("_").first
      skill.tier = defn[:tier] || 1
      skill.effect_key = defn[:effect_key]
      skill.effect_value = defn[:effect_value] || {}
      skill.requirements = defn[:requirements] || {}
    end
  end
end
