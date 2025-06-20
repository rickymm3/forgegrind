class PlayerStatsController < ApplicationController
  before_action :authenticate_user!

  # GET /player_stats
  def show
    @stat = current_user.user_stat
    @stats = [
      { label: 'HP',          key: 'hp',         level: @stat.hp_level },
      { label: 'Attack',      key: 'attack',     level: @stat.attack_level },
      { label: 'Defense',     key: 'defense',    level: @stat.defense_level },
      { label: 'Luck',        key: 'luck',       level: @stat.luck_level },
      { label: 'Attunement',  key: 'attunement', level: @stat.attunement_level }
    ]
  end

  # POST /player_stats/upgrade
  # expects param[:stat] to be one of: "hp", "attack", "defense", "luck", "attunement"
  def upgrade
    @stat = current_user.user_stat
    stat_key = "#{params[:stat]}_level"
    current_level = @stat.public_send(stat_key)
    cost = GameConfig.cost_for_level(current_level)

    if @stat.trophies < cost
      redirect_to player_stats_path, alert: "Not enough trophies (need #{cost})."
      return
    end

    @stat.transaction do
      @stat.update!(
        trophies:    @stat.trophies - cost,
        stat_key    => current_level + 1
      )
    end

    redirect_to player_stats_path,
                notice: "#{params[:stat].humanize} increased to #{current_level + 1}!"
  end
end
