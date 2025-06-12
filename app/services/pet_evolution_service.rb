class PetEvolutionService
  # Returns all EvolutionRule records applicable to this UserPet
  def self.applicable_rules(user_pet)
    EvolutionRule
      .where(parent_pet_id: user_pet.pet_id)
      .select { |rule| rule.matches?(user_pet) }
  end

  # Perform the evolution: swap species, reset EXP, clear held item
  def self.evolve!(user_pet, rule)
    user_pet.update!(
      pet_id:           rule.child_pet_id,
      exp:              0,
      held_user_item:   nil
    )
  end
end
