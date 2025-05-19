# === Currencies (legacy, safe to keep for now) ===
trophies = Currency.find_or_create_by!(name: "Trophies", symbol: "🏆")

# === Rarities ===
common    = Rarity.find_or_create_by!(name: "Common",    color: "gray",    weight: 80)
uncommon  = Rarity.find_or_create_by!(name: "Uncommon",  color: "green",   weight: 15)
rare      = Rarity.find_or_create_by!(name: "Rare",      color: "blue",    weight: 4)
legendary = Rarity.find_or_create_by!(name: "Legendary", color: "orange",  weight: 1)

# === Items (used for exploration rewards & egg costs) ===
starter_item = Item.find_or_create_by!(item_type: "starter_item") { |i| i.name = "Starter Item" }
wooden_stick = Item.find_or_create_by!(item_type: "wooden_stick") { |i| i.name = "Wooden Stick" }

# === Worlds (Exploration zones) ===
World.find_or_create_by!(name: "Starter Zone") do |w|
  w.duration = 300  # 5 minutes
  w.reward_item_type = "starter_item"
end

World.find_or_create_by!(name: "Forest") do |w|
  w.duration = 600  # 10 minutes
  w.reward_item_type = "wooden_stick"
end

# === Eggs ===
starter_egg = Egg.find_or_create_by!(name: "Starter Egg") do |e|
  e.currency = trophies
  e.cost_amount = 10   # Legacy for now, but won't be used in buying logic anymore
  e.hatch_duration = 300
end

forest_egg = Egg.find_or_create_by!(name: "Forest Egg") do |e|
  e.currency = trophies
  e.cost_amount = 50
  e.hatch_duration = 600
end

sapling_egg = Egg.find_or_create_by!(name: "Sapling Egg") do |e|
  e.currency = trophies
  e.cost_amount = 100
  e.hatch_duration = 900
end

sapling_pets = [
  { name: "Sprig",     rarity: uncommon,  power: 3 },
  { name: "Twigster",  rarity: uncommon,  power: 3 },
  { name: "Barkling",  rarity: rare,      power: 5 },
  { name: "Verdant",   rarity: legendary, power: 9 }
]

sapling_pets.each do |attrs|
  pet = sapling_egg.pets.find_or_initialize_by(name: attrs[:name])
  pet.rarity = attrs[:rarity]
  pet.power  = attrs[:power]
  pet.save!
end


# === Pets ===
starter_pets = [
  { name: "Cat",   rarity: common, power: 1 },
  { name: "Dog",   rarity: common, power: 1 },
  { name: "Mouse", rarity: common, power: 1 },
  { name: "Fish",  rarity: common, power: 1 }
]

starter_pets.each do |attrs|
  pet = starter_egg.pets.find_or_initialize_by(name: attrs[:name])
  pet.rarity = attrs[:rarity]
  pet.power  = attrs[:power]
  pet.save!
end

forest_pets = [
  { name: "Deer",   rarity: common,    power: 2 },
  { name: "Owl",    rarity: uncommon,  power: 3 },
  { name: "Bear",   rarity: rare,      power: 5 },
  { name: "Dryad",  rarity: legendary, power: 10 }
]

forest_pets.each do |attrs|
  pet = forest_egg.pets.find_or_initialize_by(name: attrs[:name])
  pet.rarity = attrs[:rarity]
  pet.power  = attrs[:power]
  pet.save!
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
