# app/controllers/battle_sessions_controller.rb
class BattleSessionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_world,         only: [:new, :create]
  before_action :ensure_enemies!,   only: [:new, :create]
  before_action :set_battle_session, only: [:attack, :sync, :complete]

  def new
    @stat           = current_user.user_stat
    @available_pets = current_user.user_pets.active
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
    @battle_session.user_pets << current_user.user_pets.active.where(id: pet_ids)

    respond_to do |format|
      format.html { redirect_to world_battle_session_path(@world) }
      format.turbo_stream { render "battle_sessions/create" }
    end
  end

  def attack
    # ... your existing attack logic ...
  end

  def complete
    payload        = JSON.parse(request.body.read)
    events         = payload["events"] || []
    claimed_status = payload["claimed_status"]

    result = BattleReplayService.new(
      world:     @battle_session.world,
      user_stat: current_user.user_stat,
      user_pets: @battle_session.user_pets,
      events:    events
    ).run

    if result.status.to_s != claimed_status.to_s
      @battle_session.destroy
      return head :unprocessable_entity
    end

    current_user.user_stat.increment!(:trophies, result.trophies) if result.status == :won

    @battle_session.destroy

    head :ok
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

  # POST /worlds/:world_id/battle_sessions/:id/wave_complete
  def wave_complete
    payload        = JSON.parse(request.body.read)
    events         = payload["events"] || []
    claimed_status = payload["claimed_status"] || "won"

    # replay just this wave
    result = BattleReplayService.new(
      world:     @battle_session.world,
      user_stat: current_user.user_stat,
      user_pets: @battle_session.user_pets,
      events:    events
    ).run_wave(@battle_session.current_enemy_index)  # -> { status:, trophies:, player_hp: }

    # reject if wave not actually won
    return head :unprocessable_entity unless result[:status] == :won

    # award trophies for this wave
    current_user.user_stat.increment!(:trophies, result[:trophies])

    next_index = @battle_session.current_enemy_index + 1

    if next_index < @battle_session.world.enemies.size
      # advance to next wave
      @battle_session.update!(current_enemy_index: next_index)

      enemy = @battle_session.world.enemies[next_index]
      render json: {
        next_enemy:       { id: enemy.id, name: enemy.name, hp: enemy.hp },
        player_hp:        result[:player_hp],
        trophies_awarded: result[:trophies],
        final:            false
      }
    else
      # last wave cleared → full victory
      @battle_session.destroy
      render json: {
        player_hp:        result[:player_hp],
        trophies_awarded: result[:trophies],
        final:            true
      }
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
