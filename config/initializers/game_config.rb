module GameConfig
  BASE_TICK_INTERVAL = 1.seconds
  BASE_ENERGY_VALUE  = 1       # energy gained per tick before multipliers

  # Player HP per HP‐level point
  HP_PER_POINT = 20
  # Player base attack per Attack‐level point
  ATTACK_PER_POINT = 5
  # Player defense per Defense‐level point
  DEFENSE_PER_POINT = 2
  # Luck multiplier for exploration and battle drops
  LUCK_MULTIPLIER = 0.05
  # Battle tick intervals (in seconds)
  PLAYER_ATTACK_INTERVAL = 2     # every 2 seconds the player auto-attacks
  ENEMY_ATTACK_INTERVAL  = 3     # every 3 seconds the enemy auto-attacks
  SYNC_INTERVAL          = 5     # client syncs counts to server every 5 seconds

  # EXP rewards per world
  WORLD_EXP = {
    "starter_zone" => 10,
    "forest"  => 20,
  }.freeze

  WORLD_DIAMONDS = {
    "starter_zone" => 50,
    "forest"       => 75,
  }.freeze

  PLAYER_LEVEL_CAP            = 20
  PLAYER_LEVEL_XP_BASE        = 100
  PLAYER_LEVEL_XP_GROWTH      = 50
  PLAYER_EXP_FOR_PET_LEVEL    = 25
  PLAYER_EXP_FOR_PET_EVOLUTION = 75
  HERO_UPGRADE_MAX_LEVEL      = 5
  HERO_UPGRADE_RESET_COST_MULTIPLIER = 100
  HERO_UPGRADES = [
    {
      key: :hatchers_luck,
      label: "Hatcher’s Luck",
      description: "Higher chance to hatch rare pets.",
      effect: "+% chance per level"
    },
    {
      key: :swift_expeditions,
      label: "Swift Expeditions",
      description: "Explore faster with short routes.",
      effect: "-% duration per level"
    },
    {
      key: :overflowing_care_boxes,
      label: "Overflowing Care Boxes",
      description: "Pet Care Boxes drop extra loot more often.",
      effect: "+% bonus drop chance per level"
    },
    {
      key: :critical_care,
      label: "Critical Care",
      description: "Pet-care consumables can crit for free extra effect.",
      effect: "+% crit chance per level"
    }
  ].freeze

  HATCHERS_LUCK_WEIGHT_BONUS_PER_RARITY = 0.08
  SWIFT_EXPEDITIONS_DURATION_REDUCTION_PER_LEVEL = 0.05
  OVERFLOWING_CARE_BOXES_BONUS_CHANCE_PER_LEVEL = 0.12
  CRITICAL_CARE_CRIT_CHANCE_PER_LEVEL = 0.1
  CRITICAL_CARE_CRIT_BONUS_MULTIPLIER = 0.5

  def self.player_level_cap
    PLAYER_LEVEL_CAP
  end

  def self.player_level_xp(level)
    level = level.to_i
    return Float::INFINITY if level >= PLAYER_LEVEL_CAP

    PLAYER_LEVEL_XP_BASE + ([level, 1].max - 1) * PLAYER_LEVEL_XP_GROWTH
  end

  def self.player_exp_for_pet_level_up
    PLAYER_EXP_FOR_PET_LEVEL
  end

  def self.player_exp_for_pet_evolution
    PLAYER_EXP_FOR_PET_EVOLUTION
  end

  def self.hero_upgrades
    HERO_UPGRADES
  end

  def self.hero_upgrade_definition(key)
    HERO_UPGRADES.find { |entry| entry[:key].to_s == key.to_s }
  end

  def self.hero_upgrade_max_level(_key = nil)
    HERO_UPGRADE_MAX_LEVEL
  end

  def self.hero_upgrade_reset_cost(player_level)
    player_level.to_i * HERO_UPGRADE_RESET_COST_MULTIPLIER
  end

  def self.hatchers_luck_multiplier(level, rarity_rank)
    level = level.to_i
    rarity_rank = rarity_rank.to_i
    return 1.0 if level <= 0 || rarity_rank <= 1

    bonus = (rarity_rank - 1) * level * HATCHERS_LUCK_WEIGHT_BONUS_PER_RARITY
    1.0 + bonus
  end

  def self.swift_expeditions_duration_multiplier(level)
    level = level.to_i
    reduction = level * SWIFT_EXPEDITIONS_DURATION_REDUCTION_PER_LEVEL
    reduction = [reduction, 0.75].min
    multiplier = 1.0 - reduction
    [multiplier, 0.25].max
  end

  def self.overflowing_care_boxes_bonus_chance(level)
    level = level.to_i
    chance = level * OVERFLOWING_CARE_BOXES_BONUS_CHANCE_PER_LEVEL
    [chance, 0.95].min
  end

  def self.critical_care_crit_chance(level)
    level = level.to_i
    chance = level * CRITICAL_CARE_CRIT_CHANCE_PER_LEVEL
    [chance, 0.95].min
  end

  def self.critical_care_crit_multiplier
    1.0 + CRITICAL_CARE_CRIT_BONUS_MULTIPLIER
  end

  # Shortcut for lookup, e.g.
  #   GameConfig.exp_for("forest")  #=> 20
  def self.exp_for(key)
    reward = ExplorationRewards.for(key)
    exp = reward.exp
    return exp if exp.positive?

    WORLD_EXP[key.to_s] || 0
  end

  def self.diamonds_for(key)
    reward = ExplorationRewards.for(key)
    diamonds = reward.diamonds
    return diamonds if diamonds.positive?

    WORLD_DIAMONDS[key.to_s] || 0
  end

  # Trophy‐cost to gain the next player level (level → cost)
  LEVEL_UP_COST = {
    1 => 5,
    2 => 15,
    3 => 50,
    4 => 120,
    5 => 250,
    # extend this map up to your chosen max level…
  }.freeze

  # Lookup trophies required to go from `level` → `level + 1`
  def self.cost_for_level(level)
    LEVEL_UP_COST[level.to_i] || Float::INFINITY
  end
end
