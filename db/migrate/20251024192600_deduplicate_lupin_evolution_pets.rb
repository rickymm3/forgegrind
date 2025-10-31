class DeduplicateLupinEvolutionPets < ActiveRecord::Migration[8.0]
  def up
    evolution_egg = Egg.find_by(name: "Lupin Evolution Forms")
    return unless evolution_egg

    duplicates = evolution_egg.pets
                               .select(:name)
                               .group(:name)
                               .having("COUNT(*) > 1")
                               .pluck(:name)

    duplicates.each do |pet_name|
      pets = evolution_egg.pets.where(name: pet_name).order(:id)
      keeper = pets.first
      next unless keeper

      pets.where.not(id: keeper.id).find_each do |duplicate|
        EvolutionRule.where(parent_pet_id: duplicate.id).update_all(parent_pet_id: keeper.id)
        EvolutionRule.where(child_pet_id: duplicate.id).update_all(child_pet_id: keeper.id)
        UserPet.where(pet_id: duplicate.id).update_all(pet_id: keeper.id)
        duplicate.destroy!
      end
    end
  end

  def down
    # irreversible deduplication
  end
end
