class PetSkill < ApplicationRecord
  RARITIES = %w[common uncommon rare epic legendary].freeze

  has_many :user_pet_skills, dependent: :destroy

  validates :name, :key, :rarity, presence: true
  validates :key, uniqueness: true
  validates :rarity, inclusion: { in: RARITIES }
  validates :tier, numericality: { only_integer: true, greater_than_or_equal_to: 1 }

  def requirements_hash
    (requirements || {}).with_indifferent_access
  end

  def meets_requirements?(user_pet)
    req = requirements_hash
    return true if req.blank?

    allowed_pet_ids = Array(req[:allowed_pet_ids]).map(&:to_i).presence
    allowed_types   = Array(req[:allowed_pet_types]).map(&:to_s).presence
    min_rarity      = req[:min_rarity]

    if allowed_pet_ids && !allowed_pet_ids.include?(user_pet.pet_id)
      return false
    end

    if allowed_types
      pet_types = user_pet.pet.pet_types.pluck(:name).map(&:downcase)
      return false if (pet_types & allowed_types.map(&:downcase)).blank?
    end

    if min_rarity
      rarity_order = RARITIES
      pet_rarity_index = rarity_order.index(user_pet.rarity&.name&.downcase)
      min_index = rarity_order.index(min_rarity.to_s.downcase)
      return false if pet_rarity_index.nil? || min_index.nil? || pet_rarity_index < min_index
    end

    true
  end
end
