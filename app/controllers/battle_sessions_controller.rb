# app/controllers/battle_sessions_controller.rb
class BattleSessionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_world,         only: [:new, :create]
  before_action :ensure_enemies!,   only: [:new, :create]
  before_action :set_battle_session, only: [:attack, :sync, :complete]

  def new
    @stat           = current_user.user_stat
    @available_pets = current_user.user_pets
    @battle_session = BattleSession.new
  end

  def create
    @stat       = current_user.user_stat
    pet_ids     = Array(params[:user_pet_ids]).map(&:to_i)
                               .first(@stat.attunement_level)
    initial_hp  = @stat.hp_level * GameConfig::HP_PER_POINT
    first_enemy = @world.enemies.first

    @battle_session = current_user.battle_sessions.create!(
      world:               @world,
      current_enemy_index: 0,
      player_hp:           initial_hp,
      enemy_hp:            first_enemy.hp,
      status:              "in_progress",
      last_sync_at:        Time.current
    )
    @battle_session.user_pets << current_user.user_pets.where(id: pet_ids)

    respond_to do |format|
      format.html { redirect_to world_battle_session_path(@world) }
      format.turbo_stream { render "battle_sessions/create" }
    end
  end

  def attack
    # ... your existing attack logic ...
  end

  def complete
    @battle_session = current_user.battle_sessions.find(params[:id])
  
    # Figure out how many waves were beaten:
    # current_enemy_index is zero‐based, so +1 = count of defeated enemies
    waves_defeated = @battle_session.current_enemy_index + 1
  
    # Collect those first N enemies
    defeated_enemies = @battle_session.world.enemies.first(waves_defeated)
  
    # Sum their trophy_reward values
    total_trophies = defeated_enemies.sum(&:trophy_reward)
  
    @battle_session.with_lock do
      if @battle_session.status == "won"
        # Credit the player
        current_user.user_stat.increment!(:trophies, total_trophies)
      end
  
      # Tear down the session
      @battle_session.destroy
    end
  
    respond_to do |format|
      format.turbo_stream
      format.html do
        if @battle_session.status == "won"
          redirect_to hero_path, notice: "Victory! You earned #{total_trophies} trophies."
        else
          redirect_to hero_path, alert: "You were defeated—no trophies this time."
        end
      end
    end

  # POST /battle_sessions/:id/sync
  def sync
    # 1) Parse the raw JSON body
    payload        = JSON.parse(request.body.read)
    last_sync_at   = Time.iso8601(payload["last_sync_at"])
    tick_events    = payload["tick_events"]    || []
    ability_events = payload["ability_events"] || []
    manual_attacks = payload["manual_attacks"] || []

    @battle_session.with_lock do
      # 2) Apply auto‐tick damage
      total_ticks = tick_events.size
      apply_auto_damage!(total_ticks)

      # 3) Replay manual attacks
      manual_attacks.each do |_ts|
        apply_manual_damage!
      end

      # 4) Replay ability events in chronological order
      ability_events
        .sort_by { |ev| ev["at"] }
        .each do |ev|
          @battle_session.use_ability!(ev["ability_id"], ev["at"])
        end

      # 5) Advance to next enemy or finish
      advance_to_next_or_complete!

      # 6) Update timestamp and persist
      @battle_session.last_sync_at = Time.current
      @battle_session.save!
    end

    # 7) Render updated UI via Turbo‐Stream
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "battle_frame",
          partial: "battle_sessions/show",
          locals: { battle_session: @battle_session, stat: current_user.user_stat }
        )
      end
    end
  end

  private

  def apply_auto_damage!(ticks)
    user_atk  = current_user.user_stat.attack_level * GameConfig::ATTACK_PER_POINT
    enemy_atk = current_enemy.attack * GameConfig::ATTACK_PER_POINT

    @battle_session.enemy_hp  -= ticks * user_atk
    @battle_session.player_hp -= ticks * enemy_atk
  end

  def apply_manual_damage!
    user_atk = current_user.user_stat.attack_level * GameConfig::ATTACK_PER_POINT
    @battle_session.enemy_hp -= user_atk
  end

  # Advances to the next enemy or marks the session won/lost
  def advance_to_next_or_complete!
    if @battle_session.enemy_hp <= 0
      idx = @battle_session.current_enemy_index + 1
      if next_enemy = @battle_session.world.enemies[idx]
        @battle_session.current_enemy_index = idx
        @battle_session.enemy_hp            = next_enemy.hp
      else
        @battle_session.status = "won"
      end
    elsif @battle_session.player_hp <= 0
      @battle_session.status = "lost"
    end
  end

  def current_enemy
    @battle_session.world.enemies[@battle_session.current_enemy_index]
  end

  def set_world
    @world = World.find(params[:world_id])
  end

  def ensure_enemies!
    if @world.enemies.empty?
      redirect_to worlds_path, alert: "No enemies configured for #{@world.name}"
    end
  end

  def set_battle_session
    @battle_session = current_user.battle_sessions.find(params[:id])
  end
end
