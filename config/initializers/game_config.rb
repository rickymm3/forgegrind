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

  # Shortcut for lookup, e.g.
  #   GameConfig.exp_for("forest")  #=> 20
  def self.exp_for(key)
    WORLD_EXP[key.to_s] || 0
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