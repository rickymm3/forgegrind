class UserPetSkill < ApplicationRecord
  belongs_to :user
  belongs_to :pet_skill
  belongs_to :equipped_user_pet, class_name: "UserPet", optional: true

  scope :equipped, -> { where.not(equipped_user_pet_id: nil) }
  scope :owned,    -> { where(equipped_user_pet_id: nil) }

  validates :quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :tier, numericality: { only_integer: true, greater_than_or_equal_to: 1 }

  def equipped?
    equipped_user_pet_id.present?
  end

  def can_equip?(user_pet, slot)
    return false if slot.nil?
    return false if equipped?
    return false unless pet_skill.meets_requirements?(user_pet)
    return false if slot.negative? || slot >= user_pet.skill_slots.to_i
    true
  end
end
