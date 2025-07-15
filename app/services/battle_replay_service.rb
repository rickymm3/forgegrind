class BattleReplayService
  attr_reader :status, :trophies

  def initialize(world:, user_stat:, user_pets:, events:)
    @world     = world
    @user_stat = user_stat
    @user_pets = user_pets
    @events    = events.map { |e| e.symbolize_keys }
  end

  def run
    setup_state
    process_events
    OpenStruct.new(status: @status, trophies: earned_trophies)
  end

  def run_wave(wave_index)
    setup_state(wave_index)

    # process only until this enemy or the player dies
    @events.sort_by { |e| e[:at].to_f }.each do |ev|
      case ev[:type]
      when "player_tick", "manual_attack"
        damage_enemy(@user_stat.attack_level * GameConfig::ATTACK_PER_POINT)
      when "enemy_tick"
        damage_player([current_enemy.attack - @user_stat.defense_level * GameConfig::DEFENSE_PER_POINT, 0].max)
      when "ability"
        use_ability(ev[:ability_id], ev[:at].to_f)
      end
      break if @enemy_hp <= 0 || @player_hp <= 0
    end

    # determine wave result
    wave_status = (@enemy_hp <= 0 && @player_hp > 0) ? :won : :lost
    trophies    = wave_status == :won ? earned_trophies : 0

    { status: wave_status, trophies: trophies, player_hp: @player_hp }
  end

  private

  def setup_state(starting_wave = 0)
    @player_hp           = @user_stat.hp_level * GameConfig::HP_PER_POINT
    @current_enemy_index = starting_wave
    @enemy_hp            = @world.enemies[@current_enemy_index].hp
    @cooldowns           = {}
    @defeated            = []
    @status              = :in_progress
  end

  def process_events
    @events.sort_by { |e| e[:at].to_f }.each do |event|
      case event[:type]
      when "player_tick"
        apply_player_damage
      when "enemy_tick"
        apply_enemy_damage
      when "manual_attack"
        apply_player_damage
      when "ability"
        use_ability(event[:ability_id], event[:at].to_f)
      end

      advance_wave if @enemy_hp <= 0
      if @status != :in_progress
        break
      elsif @player_hp <= 0
        @status = :lost
        break
      end
    end

    @status = :won if @status == :in_progress && @current_enemy_index >= @world.enemies.size
  end

  def apply_player_damage
    dmg = @user_stat.attack_level * GameConfig::ATTACK_PER_POINT
    @enemy_hp -= dmg
  end

  # helper to fetch the current enemy
  def current_enemy
    @world.enemies[@current_enemy_index]
  end

  def apply_enemy_damage
    enemy = @world.enemies[@current_enemy_index]
    dmg = [enemy.attack - @user_stat.defense_level * GameConfig::DEFENSE_PER_POINT, 0].max
    @player_hp -= dmg
  end

  def use_ability(id, timestamp)
    ability = Ability.find(id)
    last = @cooldowns[id.to_i] || -Float::INFINITY
    if last + ability.cooldown.to_i * 1000 <= timestamp
      @enemy_hp -= ability.damage
      @cooldowns[id.to_i] = timestamp
    end
  end

  def advance_wave
    @defeated << @world.enemies[@current_enemy_index]
    @current_enemy_index += 1
    if (next_enemy = @world.enemies[@current_enemy_index])
      @enemy_hp = next_enemy.hp
    else
      @status = :won
    end
  end

  def earned_trophies
    total = 0
    @defeated.each_with_index do |enemy, idx|
      base = enemy.trophy_reward_base
      growth = enemy.trophy_reward_growth
      reward = (base + growth * idx) * enemy.boss_bonus_multiplier
      total += reward
    end
    total
  end
end