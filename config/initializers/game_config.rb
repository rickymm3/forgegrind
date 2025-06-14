module GameConfig
  BASE_TICK_INTERVAL = 1.seconds
  BASE_ENERGY_VALUE  = 1       # energy gained per tick before multipliers

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
end