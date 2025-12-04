# db/seeds.rb

# === PetTypes ===
normal    = PetType.find_or_create_by!(name: "Normal")
electric  = PetType.find_or_create_by!(name: "Electric")
water     = PetType.find_or_create_by!(name: "Water")
fire      = PetType.find_or_create_by!(name: "Fire")
grass     = PetType.find_or_create_by!(name: "Grass")
ice       = PetType.find_or_create_by!(name: "Ice")
shadow    = PetType.find_or_create_by!(name: "Shadow")
metal     = PetType.find_or_create_by!(name: "Metal")
wind      = PetType.find_or_create_by!(name: "Wind")
spirit    = PetType.find_or_create_by!(name: "Spirit")
storm     = PetType.find_or_create_by!(name: "Storm")
celestial = PetType.find_or_create_by!(name: "Celestial")
beast     = PetType.find_or_create_by!(name: "Beast")

# === Currencies (legacy) ===
coins = Currency.find_or_create_by!(name: "Coins", symbol: "🪙")
diamonds = Currency.find_or_create_by!(name: "Diamonds", symbol: "💎")
glow_essence = Currency.find_or_create_by!(name: "Glow Essence", symbol: "✨")

# === Rarities ===
rarity_definitions = [
  { name: "Common",    color: "gray",   weight: 80, glow_essence_multiplier: 5 },
  { name: "Uncommon",  color: "green",  weight: 15, glow_essence_multiplier: 10 },
  { name: "Rare",      color: "blue",   weight: 4,  glow_essence_multiplier: 20 },
  { name: "Legendary", color: "orange", weight: 1,  glow_essence_multiplier: 40 }
]

rarities = rarity_definitions.each_with_object({}) do |attrs, memo|
  rarity = Rarity.find_or_initialize_by(name: attrs[:name])
  rarity.update!(attrs)
  memo[attrs[:name]] = rarity
end

common    = rarities["Common"]
uncommon  = rarities["Uncommon"]
rare      = rarities["Rare"]
legendary = rarities["Legendary"]

# === Items ===
items_config_path = Rails.root.join("config", "items.yml")
raise "Missing config/items.yml" unless items_config_path.exist?

item_definitions = YAML.load_file(items_config_path)
raise "config/items.yml is empty" unless item_definitions.present?

items = item_definitions.each_with_object({}) do |(item_type, attrs), memo|
  attrs = attrs || {}
  record = Item.find_or_initialize_by(item_type: item_type.to_s)
  record.name = attrs["name"].presence || attrs[:name].presence || item_type.to_s.humanize
  record.save!
  memo[item_type.to_sym] = record
end

starter_item      = items.fetch(:starter_item)
wooden_stick      = items.fetch(:wooden_stick)
frisbee           = items.fetch(:frisbee)
blanket           = items.fetch(:blanket)
whistle           = items.fetch(:whistle)
treat             = items.fetch(:treat)
map               = items.fetch(:map)
soap              = items.fetch(:soap)
leveling_stone    = items.fetch(:leveling_stone)
normal_stone      = items.fetch(:normal_stone)
fire_stone        = items.fetch(:fire_stone)
water_stone       = items.fetch(:water_stone)
electric_stone    = items.fetch(:electric_stone)
grass_stone       = items.fetch(:grass_stone)
ice_stone         = items.fetch(:ice_stone)
shadow_stone      = items.fetch(:shadow_stone)
metal_stone       = items.fetch(:metal_stone)
wind_stone        = items.fetch(:wind_stone)
spirit_stone      = items.fetch(:spirit_stone)
storm_stone       = items.fetch(:storm_stone)
celestial_stone   = items.fetch(:celestial_stone)

# === Special Abilities ===
special_abilities = PetSpecialAbilityCatalog.sync_definitions!
warn "⚠️  No special abilities defined. Add entries to config/special_abilities.yml." if special_abilities.blank?

# === Worlds ===
starter_zone = World.find_or_create_by!(name: "Starter Zone") do |w|
  w.duration         = 300
  w.reward_item_type = "starter_item"
  w.diamond_reward   = 50
end
starter_zone.update!(diamond_reward: 50) unless starter_zone.diamond_reward == 50
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
  w.diamond_reward   = 75
end
forest.update!(diamond_reward: 75) unless forest.diamond_reward == 75

ember_fields = World.find_or_create_by!(name: "Ember Fields") do |w|
  w.duration         = 900
  w.reward_item_type = "leveling_stone"
  w.diamond_reward   = 90
end

aurora_tundra = World.find_or_create_by!(name: "Aurora Tundra") do |w|
  w.duration         = 960
  w.reward_item_type = "ice_stone"
  w.diamond_reward   = 95
end

verdant_canopy = World.find_or_create_by!(name: "Verdant Canopy") do |w|
  w.duration         = 840
  w.reward_item_type = "grass_stone"
  w.diamond_reward   = 85
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
  e.currency       = coins
  e.cost_amount    = 10
  e.hatch_duration = 15
end
starter_egg.update!(hatch_duration: 15) unless starter_egg.hatch_duration == 15

nature_egg = Egg.find_or_create_by!(name: "Nature Egg") do |e|
  e.currency       = diamonds
  e.cost_amount    = 200
  e.hatch_duration = 900
end
nature_egg.update!(currency: diamonds, cost_amount: 200, hatch_duration: 900)

# Map Pets -> Special Abilities (optional if pets not yet seeded)
PetSpecialAbilityCatalog.backfill_pets!

# === Loot Tables & Containers ===
pet_care_loot_tables = {
  "lt_pet_care_basic" => {
    name: "Pet Care Supplies I",
    rolls_min: 1,
    rolls_max: 2,
    entries: [
      { item: treat, weight: 17, qty_min: 3, qty_max: 5, rarity: "common" },
      { item: frisbee, weight: 17, qty_min: 1, qty_max: 3, rarity: "uncommon" },
      { item: blanket, weight: 17, qty_min: 1, qty_max: 3, rarity: "uncommon" },
      { item: soap, weight: 17, qty_min: 1, qty_max: 3, rarity: "rare" },
      { item: whistle, weight: 16, qty_min: 1, qty_max: 3, rarity: "rare" },
      { item: map, weight: 16, qty_min: 3, qty_max: 5, rarity: "rare" }
    ]
  },
  "lt_pet_care_plus" => {
    name: "Pet Care Supplies II",
    rolls_min: 2,
    rolls_max: 3,
    entries: [
      { item: treat, weight: 40, qty_min: 4, qty_max: 6, rarity: "common" },
      { item: frisbee, weight: 25, qty_min: 2, qty_max: 3, rarity: "uncommon" },
      { item: blanket, weight: 20, qty_min: 1, qty_max: 2, rarity: "uncommon" },
      { item: whistle, weight: 10, qty_min: 1, qty_max: 1, rarity: "rare" },
      { item: map, weight: 5, qty_min: 1, qty_max: 1, rarity: "rare" }
    ]
  }
}

zone_loot_tables = {
  "lt_zone_starter" => {
    name: "Starter Zone Loot",
    entries: [
      { item: starter_item, weight: 0, qty_min: 1, qty_max: 1, rarity: "common", constraints: { "guaranteed" => true } },
      { item: frisbee, weight: 30, qty_min: 1, qty_max: 1, rarity: "uncommon" },
      { item: whistle, weight: 15, qty_min: 1, qty_max: 1, rarity: "uncommon" },
      { item: blanket, weight: 20, qty_min: 1, qty_max: 1, rarity: "uncommon" },
      { item: treat, weight: 20, qty_min: 1, qty_max: 1, rarity: "common" },
      { item: map, weight: 15, qty_min: 1, qty_max: 1, rarity: "uncommon" }
    ]
  },
  "lt_zone_forest" => {
    name: "Forest Loot",
    entries: [
      { item: wooden_stick, weight: 0, qty_min: 1, qty_max: 1, rarity: "common", constraints: { "guaranteed" => true } },
      { item: frisbee, weight: 30, qty_min: 1, qty_max: 1, rarity: "uncommon" },
      { item: whistle, weight: 15, qty_min: 1, qty_max: 1, rarity: "uncommon" },
      { item: blanket, weight: 20, qty_min: 1, qty_max: 1, rarity: "uncommon" },
      { item: treat, weight: 20, qty_min: 1, qty_max: 1, rarity: "common" },
      { item: map, weight: 15, qty_min: 1, qty_max: 1, rarity: "uncommon" }
    ]
  },
  "lt_zone_blazing" => {
    name: "Blazing Zone Loot",
    entries: [
      { item: fire_stone, weight: 25, qty_min: 1, qty_max: 1, rarity: "rare" },
      { item: treat, weight: 20, qty_min: 1, qty_max: 2, rarity: "common" },
      { item: whistle, weight: 10, qty_min: 1, qty_max: 1, rarity: "uncommon" }
    ]
  },
  "lt_zone_frozen" => {
    name: "Frozen Zone Loot",
    entries: [
      { item: ice_stone, weight: 25, qty_min: 1, qty_max: 1, rarity: "rare" },
      { item: blanket, weight: 20, qty_min: 1, qty_max: 1, rarity: "uncommon" },
      { item: soap, weight: 10, qty_min: 1, qty_max: 1, rarity: "uncommon" }
    ]
  },
  "lt_zone_toxic" => {
    name: "Toxic Zone Loot",
    entries: [
      { item: treat, weight: 20, qty_min: 1, qty_max: 2, rarity: "common" },
      { item: map, weight: 15, qty_min: 1, qty_max: 1, rarity: "uncommon" },
      { item: shadow_stone, weight: 25, qty_min: 1, qty_max: 1, rarity: "rare" }
    ]
  },
  "lt_zone_verdant" => {
    name: "Verdant Zone Loot",
    entries: [
      { item: grass_stone, weight: 30, qty_min: 1, qty_max: 1, rarity: "rare" },
      { item: treat, weight: 20, qty_min: 1, qty_max: 2, rarity: "common" },
      { item: map, weight: 10, qty_min: 1, qty_max: 1, rarity: "uncommon" }
    ]
  },
  "lt_zone_storm" => {
    name: "Storm Zone Loot",
    entries: [
      { item: electric_stone, weight: 20, qty_min: 1, qty_max: 1, rarity: "rare" },
      { item: wind_stone, weight: 20, qty_min: 1, qty_max: 1, rarity: "rare" },
      { item: normal_stone, weight: 10, qty_min: 1, qty_max: 1, rarity: "uncommon" }
    ]
  },
  "lt_zone_celestial" => {
    name: "Celestial Zone Loot",
    entries: [
      { item: celestial_stone, weight: 20, qty_min: 1, qty_max: 1, rarity: "epic" },
      { item: normal_stone, weight: 15, qty_min: 1, qty_max: 1, rarity: "uncommon" },
      { item: leveling_stone, weight: 10, qty_min: 1, qty_max: 1, rarity: "rare" }
    ]
  }
}

loot_tables = {}
pet_care_loot_tables.each do |key, config|
  table = LootTable.find_or_initialize_by(key: key)
  table.name = config[:name]
  table.rolls_min = config[:rolls_min]
  table.rolls_max = config[:rolls_max]
  table.save!
  loot_tables[key] = table

  config[:entries].each do |entry|
    loot_entry = LootEntry.find_or_initialize_by(loot_table: table, item: entry[:item])
    loot_entry.update!(
      weight: entry[:weight],
      qty_min: entry[:qty_min],
      qty_max: entry[:qty_max],
      rarity: entry[:rarity],
      constraints_json: entry[:constraints] || {}
    )
  end
end

pet_care_box_lvl1 = ChestType.find_or_initialize_by(key: "pet_care_box_lvl1")
pet_care_box_lvl1.update!(
  name: "Pet Care Box I",
  icon: "chests/pet_care_box_1.png",
  default_loot_table: loot_tables.fetch("lt_pet_care_basic"),
  open_batch_allowed: true,
  min_level: 1,
  visible: true
)

pet_care_box_lvl2 = ChestType.find_or_initialize_by(key: "pet_care_box_lvl2")
pet_care_box_lvl2.update!(
  name: "Pet Care Box II",
  icon: "chests/pet_care_box_2.png",
  default_loot_table: loot_tables.fetch("lt_pet_care_plus"),
  open_batch_allowed: true,
  min_level: 5,
  visible: true
)

World.find_each do |world|
  drop = ZoneChestDrop.find_or_create_by!(world: world, chest_type: pet_care_box_lvl1)
  drop.update!(weight: 100)
end

meadow_zone = World.find_by(name: "Meadow")
if meadow_zone
  ZoneChestDrop.where(world: meadow_zone).delete_all
  ZoneChestDrop.create!(world: meadow_zone, chest_type: pet_care_box_lvl1, weight: 40)
  ZoneChestDrop.create!(world: meadow_zone, chest_type: pet_care_box_lvl2, weight: 60)
end

# === Starter Pets ===
starter_pets = [
  {
    name: "Houndlet",
    rarity: common,
    power: 2,
    pet_types: [beast, spirit],
    description: "A mossy-coated guardian pup that chirps when excited. Houndlet is fiercely loyal and quick to defend new trainers venturing out for the first time.",
    hp: 22, atk: 7, def: 7, sp_atk: 6, sp_def: 7, speed: 9
  },
  {
    name: "Kittian",
    rarity: common,
    power: 2,
    pet_types: [beast, wind],
    description: "A meadow cat whose tail ends in floating leaves. Kittian stalks breezes and darts through tall grass, energizing any party with its playful pounces.",
    hp: 20, atk: 6, def: 6, sp_atk: 8, sp_def: 6, speed: 12
  },
  {
    name: "Nibblin",
    rarity: common,
    power: 2,
    pet_types: [beast, shadow],
    description: "A dusk-warren critter that hoards shiny pebbles. Nibblin loves hide-and-seek, slipping between roots before reappearing with a triumphant squeak.",
    hp: 18, atk: 8, def: 5, sp_atk: 7, sp_def: 6, speed: 11
  },
  {
    name: "Fawndrel",
    rarity: common,
    power: 2,
    pet_types: [beast, grass],
    description: "A gentle fawn with budding antlers that glow softly at night. Fawndrel hums to seedlings and inspires patience as new tamers learn the ropes.",
    hp: 24, atk: 5, def: 8, sp_atk: 6, sp_def: 8, speed: 8
  }
]

starter_pets.each do |attrs|
  pet = starter_egg.pets.find_or_initialize_by(name: attrs[:name])
  pet.assign_attributes(
    rarity:   attrs[:rarity],
    power:    attrs[:power],
    description: attrs[:description],
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

# === Nature Egg – Lupin lineage ===
nature_pet_data = [
  {
    name: "Glimmerfin",
    rarity: common,
    power: 2,
    pet_types: [water, spirit],
    description: "A curious river dweller whose scales shimmer with bioluminescent freckles. Glimmerfin hums softly to soothe anxious trainers and splashes whenever it senses hidden coves.",
    hp: 19, atk: 5, def: 6, sp_atk: 9, sp_def: 7, speed: 10
  },
  {
    name: "Noctwing",
    rarity: common,
    power: 2,
    pet_types: [shadow, wind],
    description: "A midnight roost companion that glides without a sound. Noctwing maps the night sky with sweeping loops, guiding wanderers by the faint glow on its wingtips.",
    hp: 18, atk: 7, def: 5, sp_atk: 7, sp_def: 6, speed: 13
  },
  {
    name: "Lupin",
    rarity: common,
    power: 3,
    pet_types: [spirit, beast],
    description: "A curious wolf pup brimming with potential. Though small, its alert eyes and playful growls hint at the fierce predator it will become. Known for forming early bonds with its trainer.",
    hp: 18, atk: 8, def: 6, sp_atk: 7, sp_def: 6, speed: 11
  },
  {
    name: "Fenra",
    rarity: uncommon,
    power: 6,
    pet_types: [ice, spirit, beast],
    description: "A swift frost wolf whose paws leave trails of snowflakes. Agile and precise, Fenra hunts silently across frozen plains, channeling ice energy through its mane.",
    hp: 25, atk: 9, def: 8, sp_atk: 12, sp_def: 9, speed: 14
  },
  {
    name: "Blazewulf",
    rarity: uncommon,
    power: 6,
    pet_types: [fire, spirit, beast],
    description: "A fiery predator whose embered fur burns with living heat. Its rage fuels its strength, and its howl can ignite the air itself. Fiercely loyal yet volatile.",
    hp: 28, atk: 14, def: 8, sp_atk: 10, sp_def: 7, speed: 12
  },
  {
    name: "Duskhound",
    rarity: uncommon,
    power: 6,
    pet_types: [shadow, spirit, beast],
    description: "A shadow-born wolf that moves unseen in moonlight. Its eyes glow through the mist, and its presence alone chills prey into stillness. Loyal to the dark, but not evil.",
    hp: 24, atk: 11, def: 7, sp_atk: 11, sp_def: 8, speed: 13
  },
  {
    name: "Ironfang",
    rarity: rare,
    power: 7,
    pet_types: [metal, spirit, beast],
    description: "A battle-hardened wolf coated in metallic fur. Forged through countless fights, its armor-like pelt deflects both magic and steel. The sound of its claws striking stone echoes like a forge.",
    hp: 32, atk: 15, def: 14, sp_atk: 9, sp_def: 12, speed: 10
  },
  {
    name: "Galeclaw",
    rarity: rare,
    power: 7,
    pet_types: [wind, spirit, beast],
    description: "A wolf infused with the spirit of wind. Its speed is legendary—able to vanish in a blur and strike before its echo fades. Known for freedom and defiance.",
    hp: 26, atk: 12, def: 8, sp_atk: 13, sp_def: 10, speed: 16
  },
  {
    name: "Fenshadow",
    rarity: rare,
    power: 7,
    pet_types: [shadow, spirit, beast],
    description: "A spectral wolf of fog and memory. Its body flickers between realms, haunting forests it once called home. Said to protect lost spirits and guide them through mist.",
    hp: 24, atk: 12, def: 9, sp_atk: 14, sp_def: 12, speed: 12
  },
  {
    name: "Verdant",
    rarity: legendary,
    power: 8,
    pet_types: [grass, spirit, celestial],
    description: "A radiant guardian deer whose antlers bloom with living vines. Verdant carries the dawn’s first light in its mane and calms even the fiercest storms with a single breath.",
    hp: 32, atk: 11, def: 13, sp_atk: 16, sp_def: 17, speed: 11
  },
  {
    name: "Pyrolune",
    rarity: legendary,
    power: 9,
    pet_types: [fire, celestial, beast],
    description: "A celestial wolf wreathed in divine flame. Its golden fire burns only what is corrupt, and its eyes reflect the light of distant stars. Revered as a guardian spirit.",
    hp: 34, atk: 16, def: 10, sp_atk: 18, sp_def: 14, speed: 15
  },
  {
    name: "Tempestral",
    rarity: legendary,
    power: 9,
    pet_types: [storm, wind, beast],
    description: "A storm-forged wolf charged with lightning. Each step hums with energy, and its howl splits the skies. Embodies unrestrained force and wild balance.",
    hp: 30, atk: 13, def: 11, sp_atk: 17, sp_def: 13, speed: 17
  },
  {
    name: "Steelbane",
    rarity: legendary,
    power: 9,
    pet_types: [metal, spirit, beast],
    description: "An alpha clad in iron plates, its scars turned to armor. Once a warrior’s companion, now a living fortress. Commands respect through presence alone.",
    hp: 38, atk: 18, def: 17, sp_atk: 12, sp_def: 15, speed: 10
  },
  {
    name: "Aetherfang",
    rarity: legendary,
    power: 10,
    pet_types: [celestial, spirit, beast],
    description: "The final ascendant form of the wolf line. Its body glows with celestial runes, fur blending into the night sky. Aetherfang moves between worlds, serving as both protector and omen.",
    hp: 36, atk: 17, def: 14, sp_atk: 20, sp_def: 18, speed: 18
  }
]

nature_base_names = %w[Glimmerfin Noctwing Lupin Verdant]

nature_pets = nature_pet_data.each_with_object({}) do |attrs, memo|
  pet = Pet.find_or_initialize_by(name: attrs[:name])
  pet.egg = nature_base_names.include?(attrs[:name]) ? nature_egg : nil
  pet.assign_attributes(
    rarity:      attrs[:rarity],
    power:       attrs[:power],
    description: attrs[:description],
    hp:          attrs[:hp],
    atk:         attrs[:atk],
    def:         attrs[:def],
    sp_atk:      attrs[:sp_atk],
    sp_def:      attrs[:sp_def],
    speed:       attrs[:speed]
  )
  pet.save!
  pet.pet_types = attrs[:pet_types]
  memo[attrs[:name]] = pet
end

lupin      = nature_pets["Lupin"]
fenra      = nature_pets["Fenra"]
blazewulf  = nature_pets["Blazewulf"]
duskhound  = nature_pets["Duskhound"]

if lupin && fenra && blazewulf && duskhound
  lupin_rules = [
    {
      parent: lupin,
      child:  fenra,
      trigger_level: 5,
      priority: 20,
      guard: {
        "any" => [
          { "type" => "need_at_least", "key" => "mood", "value" => 70 },
          { "type" => "sum_traits_at_least", "keys" => ["affection", "playfulness"], "value" => 60 }
        ]
      },
      notes: "Happy Lupin evolves at level 5"
    },
    {
      parent: lupin,
      child:  blazewulf,
      trigger_level: nil,
      window_min_level: 10,
      window_max_level: 10,
      priority: 15,
      guard: {
        "all" => [
          { "type" => "flag_true", "key" => "missed_lvl5_happiness" },
          { "type" => "need_at_most", "key" => "mood", "value" => 69 },
          { "type" => "trait_at_least", "key" => "temperament", "value" => 40 }
        ]
      },
      notes: "Angry Lupin finds power through fire at level 10"
    },
    {
      parent: lupin,
      child:  duskhound,
      trigger_level: nil,
      window_min_level: 10,
      window_max_level: 10,
      priority: 14,
      guard: {
        "all" => [
          { "type" => "flag_true", "key" => "missed_lvl5_happiness" },
          { "type" => "need_at_least", "key" => "mood", "value" => 70 }
        ],
        "any" => [
          { "type" => "season_is", "value" => "winter" },
          { "type" => "sum_traits_at_least", "keys" => ["confidence", "curiosity"], "value" => 55 }
        ]
      },
      notes: "Resilient Lupin embraces the shadows after missing its first window",
      seasonal_tag: "winter"
    }
  ]

lupin_rules.each do |attrs|
  lookup = {
    parent_pet: attrs[:parent],
    child_pet:  attrs[:child],
      trigger_level: attrs[:trigger_level],
      window_min_level: attrs[:window_min_level],
      window_max_level: attrs[:window_max_level],
      window_event: attrs[:window_event]
    }

    rule = EvolutionRule.find_or_initialize_by(lookup)
    rule.parent_pet    = attrs[:parent]
    rule.child_pet     = attrs[:child]
    rule.trigger_level = attrs[:trigger_level]
    rule.window_min_level = attrs[:window_min_level]
    rule.window_max_level = attrs[:window_max_level]
    rule.window_event  = attrs[:window_event]
    rule.priority      = attrs[:priority]
    rule.one_shot      = true
    rule.guard_json    = attrs[:guard]
    rule.seasonal_tag  = attrs[:seasonal_tag]
    rule.notes         = attrs[:notes]
    rule.save!
  end
end

EvolutionRuleLoader.sync!

abilities = [
  {
    name:         "Tackle",
    reference:    "tackle",
    description:  "A basic physical ram that deals light damage.",
    element_type: "physical"
  },
  {
    name:         "Growl",
    reference:    "growl",
    description:  "Intimidates the foe, lowering its speed.",
    element_type: "status"
  },
  {
    name:         "Whirlwind",
    reference:    "whirlwind",
    description:  "A rare wind gust that strikes swiftly and can hit multiple foes.",
    element_type: "wind"
  },
  {
    name:         "Ember Burst",
    reference:    "ember_burst",
    description:  "Ignites the air around the foe with a burst of flame.",
    element_type: "fire"
  },
  {
    name:         "Frost Shard",
    reference:    "frost_shard",
    description:  "Launches a razor shard of ice that chills the target.",
    element_type: "ice"
  },
  {
    name:         "Tempest Slash",
    reference:    "tempest_slash",
    description:  "Channels slicing winds into a cutting strike.",
    element_type: "wind"
  },
  {
    name:         "Venom Dart",
    reference:    "venom_dart",
    description:  "Fires a toxic barb that leaves foes reeling.",
    element_type: "poison"
  },
  {
    name:         "Shadow Bind",
    reference:    "shadow_bind",
    description:  "Wraps the foe in living shadows, sapping their strength.",
    element_type: "shadow"
  }
]

abilities.each do |attrs|
  ability = Ability.find_or_initialize_by(reference: attrs[:reference])
  ability.name         = attrs[:name]
  ability.description  = attrs[:description]
  ability.element_type = attrs[:element_type]
  ability.save!
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

# === Retroactive type associations ===
Pet.find_each do |pet|
  pet.pet_types << normal if pet.pet_types.empty?
end

World.find_each do |world|
  if world.name == "Forest" && world.pet_types.empty?
    world.pet_types << grass
  end
end
