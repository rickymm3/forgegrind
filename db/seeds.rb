# db/seeds.rb

# === PetTypes ===
normal    = PetType.find_or_create_by!(name: "Normal")
electric  = PetType.find_or_create_by!(name: "Electric")
water     = PetType.find_or_create_by!(name: "Water")
fire      = PetType.find_or_create_by!(name: "Fire")
grass     = PetType.find_or_create_by!(name: "Grass")

# === Currencies (legacy) ===
trophies = Currency.find_or_create_by!(name: "Trophies", symbol: "🏆")

# === Rarities ===
common    = Rarity.find_or_create_by!(name: "Common",    color: "gray",    weight: 80)
uncommon  = Rarity.find_or_create_by!(name: "Uncommon",  color: "green",   weight: 15)
rare      = Rarity.find_or_create_by!(name: "Rare",      color: "blue",    weight: 4)
legendary = Rarity.find_or_create_by!(name: "Legendary", color: "orange",  weight: 1)

# === Items ===
starter_item = Item.find_or_create_by!(item_type: "starter_item") { |i| i.name = "Starter Item" }
wooden_stick = Item.find_or_create_by!(item_type: "wooden_stick")   { |i| i.name = "Wooden Stick" }
frisbee      = Item.find_or_create_by!(item_type: "frisbee")        { |i| i.name = "Frisbee" }
blanket      = Item.find_or_create_by!(item_type: "blanket")        { |i| i.name = "Blanket" }
whistle      = Item.find_or_create_by!(item_type: "whistle")        { |i| i.name = "Whistle" }
treat        = Item.find_or_create_by!(item_type: "treat")          { |i| i.name = "Treat" }
map          = Item.find_or_create_by!(item_type: "map")            { |i| i.name = "Map" }

# === Worlds ===
starter_zone = World.find_or_create_by!(name: "Starter Zone") do |w|
  w.duration         = 300
  w.reward_item_type = "starter_item"
end
# clear existing waves
starter_zone.enemies.destroy_all
# recreate waves with base/growth and boss multiplier
starter_zone.enemies.create!([
  { name: "Training Dummy",
    hp: 50, attack:  5, defense: 1,
    trophy_reward_base:   5,
    trophy_reward_growth: 0,
    boss_bonus_multiplier: 1.0
  },
  { name: "Woodland Scout",
    hp: 100, attack: 10, defense: 3,
    trophy_reward_base:   10,
    trophy_reward_growth:  2,
    boss_bonus_multiplier: 1.0
  },
  { name: "Forest Brute",
    hp: 150, attack: 15, defense: 5,
    trophy_reward_base:   20,
    trophy_reward_growth:  5,
    boss_bonus_multiplier: 1.0
  },
  { name: "Mini-Boss",
    hp: 200, attack: 20, defense: 8,
    trophy_reward_base:   30,
    trophy_reward_growth: 10,
    boss_bonus_multiplier: 1.0
  },
  { name: "Zone Boss",
    hp: 300, attack: 25, defense: 10,
    trophy_reward_base:   50,
    trophy_reward_growth: 10,
    boss_bonus_multiplier: 2.5
  }
])

forest = World.find_or_create_by!(name: "Forest") do |w|
  w.duration         = 600
  w.reward_item_type = "wooden_stick"
end
forest.enemies.destroy_all
forest.enemies.create!([
  { name: "Wolf",
    hp:  60, attack:  8, defense: 2,
    trophy_reward_base:   8,
    trophy_reward_growth: 0,
    boss_bonus_multiplier: 1.0
  },
  { name: "Entling",
    hp: 120, attack: 12, defense: 4,
    trophy_reward_base:   15,
    trophy_reward_growth:  3,
    boss_bonus_multiplier: 1.0
  },
  { name: "Bear",
    hp: 180, attack: 18, defense: 7,
    trophy_reward_base:   25,
    trophy_reward_growth:  5,
    boss_bonus_multiplier: 1.0
  },
  { name: "Forest Lord",
    hp: 250, attack: 22, defense: 12,
    trophy_reward_base:   40,
    trophy_reward_growth: 10,
    boss_bonus_multiplier: 2.0
  }
])

# associate grass type for Forest
forest.pet_types = [grass]

# === Eggs ===
starter_egg = Egg.find_or_create_by!(name: "Starter Egg") do |e|
  e.currency       = trophies
  e.cost_amount    = 10
  e.hatch_duration = 300
end

forest_egg = Egg.find_or_create_by!(name: "Forest Egg") do |e|
  e.currency       = trophies
  e.cost_amount    = 50
  e.hatch_duration = 600
end

sapling_egg = Egg.find_or_create_by!(name: "Sapling Egg") do |e|
  e.currency       = trophies
  e.cost_amount    = 100
  e.hatch_duration = 900
end

# === Sapling Pets ===
sapling_pets = [
  { name: "Sprig",    rarity: uncommon,  power: 3, pet_types: [water],
    hp: 12, atk:  6, def:  5, sp_atk:  7, sp_def:  5, speed:  6 },
  { name: "Twigster", rarity: uncommon,  power: 3, pet_types: [water],
    hp: 11, atk:  7, def:  6, sp_atk:  6, sp_def:  5, speed:  7 },
  { name: "Barkling", rarity: rare,      power: 5, pet_types: [fire],
    hp: 20, atk:  8, def:  8, sp_atk:  4, sp_def:  6, speed:  4 },
  { name: "Verdant",  rarity: legendary, power: 9, pet_types: [electric],
    hp: 25, atk:  5, def: 10, sp_atk: 15, sp_def: 15, speed:  5 }
]

sapling_pets.each do |attrs|
  pet = sapling_egg.pets.find_or_initialize_by(name: attrs[:name])
  pet.assign_attributes(
    rarity:   attrs[:rarity],
    power:    attrs[:power],
    hp:       attrs[:hp],
    atk:      attrs[:atk],
    def:      attrs[:def],
    sp_atk:   attrs[:sp_atk],
    sp_def:   attrs[:sp_def],
    speed:    attrs[:speed]
  )
  pet.save!
  pet.pet_types = attrs[:pet_types]
end

# === Starter Pets ===
starter_pets = [
  { name: "Cat",   rarity: common,   power: 1, pet_types: [fire],
    hp: 10, atk:  5, def:  5, sp_atk:  2, sp_def:  3, speed:  7 },
  { name: "Dog",   rarity: common,   power: 1, pet_types: [fire],
    hp: 10, atk:  6, def:  5, sp_atk:  3, sp_def:  3, speed:  6 },
  { name: "Mouse", rarity: common,   power: 1, pet_types: [electric],
    hp:  8, atk:  4, def:  4, sp_atk:  3, sp_def:  2, speed: 10 },
  { name: "Fish",  rarity: common,   power: 1, pet_types: [water],
    hp:  7, atk:  3, def:  3, sp_atk:  5, sp_def:  6, speed:  5 }
]

starter_pets.each do |attrs|
  pet = starter_egg.pets.find_or_initialize_by(name: attrs[:name])
  pet.assign_attributes(
    rarity:   attrs[:rarity],
    power:    attrs[:power],
    hp:       attrs[:hp],
    atk:      attrs[:atk],
    def:      attrs[:def],
    sp_atk:   attrs[:sp_atk],
    sp_def:   attrs[:sp_def],
    speed:    attrs[:speed]
  )
  pet.save!
  pet.pet_types = attrs[:pet_types]
end

# === Forest Pets ===
forest_pets = [
  { name: "Deer",  rarity: common,    power: 2, pet_types: [water],
    hp: 20, atk:  7, def:  6, sp_atk:  3, sp_def:  4, speed:  6 },
  { name: "Owl",   rarity: uncommon,  power: 3, pet_types: [electric],
    hp: 15, atk:  5, def:  5, sp_atk:  8, sp_def:  5, speed:  8 },
  { name: "Bear",  rarity: rare,      power: 5, pet_types: [fire],
    hp: 30, atk: 10, def: 10, sp_atk:  2, sp_def:  3, speed:  4 },
  { name: "Dryad", rarity: legendary, power:10, pet_types: [grass],
    hp: 18, atk:  4, def:  6, sp_atk: 12, sp_def: 10, speed:  5 }
]

forest_pets.each do |attrs|
  pet = forest_egg.pets.find_or_initialize_by(name: attrs[:name])
  pet.assign_attributes(
    rarity:   attrs[:rarity],
    power:    attrs[:power],
    hp:       attrs[:hp],
    atk:      attrs[:atk],
    def:      attrs[:def],
    sp_atk:   attrs[:sp_atk],
    sp_def:   attrs[:sp_def],
    speed:    attrs[:speed]
  )
  pet.save!
  pet.pet_types = attrs[:pet_types]
end

# === PetThoughts ===
PetThought.find_or_create_by!(thought: "I’m feeling playful!") do |pt|
  pt.playfulness_mod = 1.5
  pt.affection_mod   = 1.2
  pt.temperament_mod = 0.8
  pt.curiosity_mod   = 1.3
  pt.confidence_mod  = 1.0
end

PetThought.find_or_create_by!(thought: "I’m a bit grumpy today.") do |pt|
  pt.playfulness_mod = 0.5
  pt.affection_mod   = 0.7
  pt.temperament_mod = 1.5
  pt.curiosity_mod   = 0.9
  pt.confidence_mod  = 1.1
end

PetThought.find_or_create_by!(thought: "I feel so curious!") do |pt|
  pt.playfulness_mod = 1.2
  pt.affection_mod   = 1.0
  pt.temperament_mod = 0.9
  pt.curiosity_mod   = 1.6
  pt.confidence_mod  = 1.0
end

# === Egg Item Costs ===
EggItemCost.find_or_create_by!(egg: starter_egg, item: starter_item) { |eic| eic.quantity = 1 }
EggItemCost.find_or_create_by!(egg: forest_egg,  item: wooden_stick) { |eic| eic.quantity = 1 }
EggItemCost.find_or_create_by!(egg: sapling_egg, item: starter_item) { |eic| eic.quantity = 1 }
EggItemCost.find_or_create_by!(egg: sapling_egg, item: wooden_stick) { |eic| eic.quantity = 1 }

# === Retroactive type associations ===
Pet.find_each do |pet|
  pet.pet_types << normal if pet.pet_types.empty?
end

World.find_each do |world|
  if world.name == "Forest" && world.pet_types.empty?
    world.pet_types << grass
  end
end
