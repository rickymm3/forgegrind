class MoveLupinEvolutionPetsToDisabledEgg < ActiveRecord::Migration[8.0]
  def up
    nature_egg = Egg.find_by(name: "Nature Egg")
    return unless nature_egg

    diamonds = Currency.find_by(name: "Diamonds")
    evolution_egg = Egg.find_or_initialize_by(name: "Lupin Evolution Forms")
    evolution_egg.currency       = diamonds if diamonds
    evolution_egg.cost_amount    = evolution_egg.cost_amount.presence || 0
    evolution_egg.hatch_duration = evolution_egg.hatch_duration.presence || 0
    evolution_egg.enabled        = false
    evolution_egg.save!

    nature_egg.pets.where.not(name: "Lupin").find_each do |pet|
      pet.update!(egg: evolution_egg)
    end
  end

  def down
    nature_egg    = Egg.find_by(name: "Nature Egg")
    evolution_egg = Egg.find_by(name: "Lupin Evolution Forms")
    return unless nature_egg && evolution_egg

    evolution_egg.pets.update_all(egg_id: nature_egg.id)
  end
end
