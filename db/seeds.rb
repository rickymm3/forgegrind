# db/seeds.rb

# === PetTypes ===
normal    = PetType.find_or_create_by!(name: "Normal")
electric  = PetType.find_or_create_by!(name: "Electric")
water     = PetType.find_or_create_by!(name: "Water")
fire      = PetType.find_or_create_by!(name: "Fire")
grass     = PetType.find_or_create_by!(name: "Grass")

# === Currencies (legacy, safe to keep for now) ===
trophies = Currency.find_or_create_by!(name: "Trophies", symbol: "🏆")

# === Rarities ===
common    = Rarity.find_or_create_by!(name: "Common",    color: "gray",    weight: 80)
uncommon  = Rarity.find_or_create_by!(name: "Uncommon",  color: "green",   weight: 15)
rare      = Rarity.find_or_create_by!(name: "Rare",      color: "blue",    weight: 4)
legendary = Rarity.find_or_create_by!(name: "Legendary", color: "orange",  weight: 1)

# === Items (used for exploration rewards & egg costs) ===
starter_item = Item.find_or_create_by!(item_type: "starter_item") { |i| i.name = "Starter Item" }
wooden_stick = Item.find_or_create_by!(item_type: "wooden_stick")   { |i| i.name = "Wooden Stick" }
frisbee      = Item.find_or_create_by!(item_type: "frisbee")        { |i| i.name = "Frisbee" }
blanket      = Item.find_or_create_by!(item_type: "blanket")        { |i| i.name = "Blanket" }
whistle      = Item.find_or_create_by!(item_type: "whistle")        { |i| i.name = "Whistle" }
treat        = Item.find_or_create_by!(item_type: "treat")          { |i| i.name = "Treat" }
map          = Item.find_or_create_by!(item_type: "map")            { |i| i.name = "Map" }

# === Worlds (Exploration zones) ===
starter_zone = World.find_or_create_by!(name: "Starter Zone") do |w|
  w.duration         = 300  # 5 minutes
  w.reward_item_type = "starter_item"
end

forest = World.find_or_create_by!(name: "Forest") do |w|
  w.duration         = 600  # 10 minutes
  w.reward_item_type = "wooden_stick"
end

# Associate types with worlds:
# Starter Zone has no pet_types
forest.pet_types = [grass]

# === Eggs ===
starter_egg = Egg.find_or_create_by!(name: "Starter Egg") do |e|
  e.currency       = trophies
  e.cost_amount    = 10   # Legacy for now
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
  { name: "Sprig",     rarity: uncommon,  power: 3, pet_types: [water],
    hp: 12, atk:  6, def:  5, sp_atk:  7, sp_def:  5, speed:  6 },
  { name: "Twigster",  rarity: uncommon,  power: 3, pet_types: [water],
    hp: 11, atk:  7, def:  6, sp_atk:  6, sp_def:  5, speed:  7 },
  { name: "Barkling",  rarity: rare,      power: 5, pet_types: [fire],
    hp: 20, atk:  8, def:  8, sp_atk:  4, sp_def:  6, speed:  4 },
  { name: "Verdant",   rarity: legendary, power: 9, pet_types: [electric],
    hp: 25, atk:  5, def: 10, sp_atk: 15, sp_def: 15, speed:  5 }
]

sapling_pets.each do |attrs|
  pet = sapling_egg.pets.find_or_initialize_by(name: attrs[:name])
  pet.rarity   = attrs[:rarity]
  pet.power    = attrs[:power]
  pet.hp       = attrs[:hp]
  pet.atk      = attrs[:atk]
  pet.def      = attrs[:def]
  pet.sp_atk   = attrs[:sp_atk]
  pet.sp_def   = attrs[:sp_def]
  pet.speed    = attrs[:speed]
  pet.save!
  pet.pet_types = attrs[:pet_types]
end

# === Starter Pets ===
starter_pets = [
  { name: "Cat",   rarity: common,  power: 1, pet_types: [fire],
    hp: 10, atk:  5, def:  5, sp_atk:  2, sp_def:  3, speed:  7 },
  { name: "Dog",   rarity: common,  power: 1, pet_types: [fire],
    hp: 10, atk:  6, def:  5, sp_atk:  3, sp_def:  3, speed:  6 },
  { name: "Mouse", rarity: common,  power: 1, pet_types: [electric],
    hp:  8, atk:  4, def:  4, sp_atk:  3, sp_def:  2, speed: 10 },
  { name: "Fish",  rarity: common,  power: 1, pet_types: [water],
    hp:  7, atk:  3, def:  3, sp_atk:  5, sp_def:  6, speed:  5 }
]

starter_pets.each do |attrs|
  pet = starter_egg.pets.find_or_initialize_by(name: attrs[:name])
  pet.rarity   = attrs[:rarity]
  pet.power    = attrs[:power]
  pet.hp       = attrs[:hp]
  pet.atk      = attrs[:atk]
  pet.def      = attrs[:def]
  pet.sp_atk   = attrs[:sp_atk]
  pet.sp_def   = attrs[:sp_def]
  pet.speed    = attrs[:speed]
  pet.save!
  pet.pet_types = attrs[:pet_types]
end

# === Forest Pets ===
forest_pets = [
  { name: "Deer",   rarity: common,    power: 2, pet_types: [water],
    hp: 20, atk:  7, def:  6, sp_atk:  3, sp_def:  4, speed:  6 },
  { name: "Owl",    rarity: uncommon,  power: 3, pet_types: [electric],
    hp: 15, atk:  5, def:  5, sp_atk:  8, sp_def:  5, speed:  8 },
  { name: "Bear",   rarity: rare,      power: 5, pet_types: [fire],
    hp: 30, atk: 10, def: 10, sp_atk:  2, sp_def:  3, speed:  4 },
  { name: "Dryad",  rarity: legendary, power: 10, pet_types: [grass],
    hp: 18, atk:  4, def:  6, sp_atk: 12, sp_def: 10, speed:  5 }
]

forest_pets.each do |attrs|
  pet = forest_egg.pets.find_or_initialize_by(name: attrs[:name])
  pet.rarity   = attrs[:rarity]
  pet.power    = attrs[:power]
  pet.hp       = attrs[:hp]
  pet.atk      = attrs[:atk]
  pet.def      = attrs[:def]
  pet.sp_atk   = attrs[:sp_atk]
  pet.sp_def   = attrs[:sp_def]
  pet.speed    = attrs[:speed]
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

# === Egg Item Costs (new model based) ===
EggItemCost.find_or_create_by!(egg: starter_egg, item: starter_item) do |eic|
  eic.quantity = 1
end

EggItemCost.find_or_create_by!(egg: forest_egg, item: wooden_stick) do |eic|
  eic.quantity = 1
end

EggItemCost.find_or_create_by!(egg: sapling_egg, item: starter_item) do |eic|
  eic.quantity = 1
end

EggItemCost.find_or_create_by!(egg: sapling_egg, item: wooden_stick) do |eic|
  eic.quantity = 1
end

# === Retroactive association for any existing pets or worlds still missing types ===
Pet.find_each do |pet|
  if pet.pet_types.empty?
    pet.pet_types << normal
  end
end

World.find_each do |world|
  if world.pet_types.empty? && world.name == "Forest"
    world.pet_types << grass
  end
  # Starter Zone already has no types; no change needed
end
