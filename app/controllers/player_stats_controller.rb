class PlayerStatsController < ApplicationController
  before_action :authenticate_user!

  # GET /player_stats
  def show
    @stat = current_user.ensure_user_stat
    @currency_balances = helpers.currency_balances_for(current_user)
    @stats = [
      { label: 'HP',          key: 'hp',         level: @stat.hp_level },
      { label: 'Attack',      key: 'attack',     level: @stat.attack_level },
      { label: 'Defense',     key: 'defense',    level: @stat.defense_level },
      { label: 'Luck',        key: 'luck',       level: @stat.luck_level },
      { label: 'Attunement',  key: 'attunement', level: @stat.attunement_level }
    ]

    @hero_points_available = @stat.available_hero_points
    @hero_points_spent     = @stat.spent_hero_points
    @reset_cost            = hero_reset_cost(@stat.player_level)
    @diamond_balance       = current_user.currency_balance(:diamonds)
    @hero_upgrades = hero_upgrade_definitions.map do |definition|
      key   = definition[:key].to_s
      level = @stat.hero_upgrade_level(key)
      cost  = @stat.hero_upgrade_cost(key)
      definition.merge(
        key: key,
        level: level,
        max_level: hero_upgrade_max_level(key),
        cost: cost,
        can_upgrade: cost.present? && @hero_points_available >= cost,
        effect: hero_upgrade_effect_text(key, level)
      )
    end
  end

  # POST /player_stats/upgrade
  # expects param[:stat] to be one of: "hp", "attack", "defense", "luck", "attunement"
  def upgrade
    @stat = current_user.ensure_user_stat
    stat_key = "#{params[:stat]}_level"
    current_level = @stat.public_send(stat_key)
    cost = GameConfig.cost_for_level(current_level)
    coins_currency = Currency.find_by_key(:coins)
    unless coins_currency
      redirect_to player_stats_path, alert: "Coins currency not configured."
      return
    end
    coin_balance = current_user.currency_balance(coins_currency)

    if coin_balance < cost
      redirect_to player_stats_path, alert: "Not enough coins (need #{cost})."
      return
    end

    @stat.transaction do
      current_user.debit_currency!(coins_currency, cost)
      @stat.update!(stat_key => current_level + 1)
    end

    redirect_to hero_path,
                notice: "#{params[:stat].humanize} increased to #{current_level + 1}!"
  end

  def upgrade_hero_stat
    @stat = current_user.ensure_user_stat
    key = params[:hero_stat].to_s

    begin
      @stat.upgrade_hero_stat!(key)
      label = hero_upgrade_definition(key)&.dig(:label) || key.humanize
      redirect_to hero_path, notice: "#{label} improved to level #{@stat.hero_upgrade_level(key)}."
    rescue => e
      redirect_to hero_path, alert: e.message
    end
  end

  def reset_hero_stats
    @stat = current_user.ensure_user_stat
    cost = hero_reset_cost(@stat.player_level)
    diamonds_currency = Currency.find_by_key(:diamonds)
    unless diamonds_currency
      redirect_to hero_path, alert: "Diamonds currency not configured."
      return
    end
    diamond_balance = current_user.currency_balance(diamonds_currency)

    if diamond_balance < cost
      redirect_to hero_path, alert: "Need #{cost} diamonds to reset hero upgrades."
      return
    end

    @stat.transaction do
      current_user.debit_currency!(diamonds_currency, cost)
      @stat.reset_hero_stats!
    end

    redirect_to hero_path, notice: "Hero upgrades reset."
  end

  private

  def hero_upgrade_definitions
    upgrades =
      if GameConfig.respond_to?(:hero_upgrades)
        GameConfig.hero_upgrades
      elsif GameConfig.const_defined?(:HERO_UPGRADES)
        GameConfig::HERO_UPGRADES
      else
        nil
      end

    Array(upgrades).presence || default_hero_upgrades
  end

  def hero_upgrade_definition(key)
    hero_upgrade_definitions.find { |entry| entry[:key].to_s == key.to_s }
  end

  def hero_upgrade_max_level(key)
    if GameConfig.respond_to?(:hero_upgrade_max_level)
      GameConfig.hero_upgrade_max_level(key)
    elsif GameConfig.const_defined?(:HERO_UPGRADE_MAX_LEVEL)
      GameConfig::HERO_UPGRADE_MAX_LEVEL
    else
      5
    end
  end

  def hero_upgrade_effect_text(key, level)
    level = level.to_i
    return "No bonus yet" if level <= 0

    case key.to_sym
    when :hatchers_luck
      bonus = (level * GameConfig::HATCHERS_LUCK_WEIGHT_BONUS_PER_RARITY * 100).round(1)
      "+#{bonus}% weight per rarity tier above Common"
    when :swift_expeditions
      reduction = ((1.0 - GameConfig.swift_expeditions_duration_multiplier(level)) * 100).round(1)
      reduction.positive? ? "-#{reduction}% expedition duration" : "No reduction"
    when :overflowing_care_boxes
      chance = (GameConfig.overflowing_care_boxes_bonus_chance(level) * 100).round(1)
      "#{chance}% chance for an extra reward roll per box"
    when :critical_care
      chance = (GameConfig.critical_care_crit_chance(level) * 100).round(1)
      bonus = ((GameConfig.critical_care_crit_multiplier - 1.0) * 100).round(0)
      "#{chance}% chance to add +#{bonus}% effect to care actions"
    else
      hero_upgrade_definition(key)&.dig(:description) || ""
    end
  rescue StandardError
    hero_upgrade_definition(key)&.dig(:description).to_s
  end

  def default_hero_upgrades
    [
      {
        key: :hatchers_luck,
        label: "Hatcher’s Luck",
        description: "Higher chance to hatch rare pets."
      },
      {
        key: :swift_expeditions,
        label: "Swift Expeditions",
        description: "Reduces expedition duration."
      },
      {
        key: :overflowing_care_boxes,
        label: "Overflowing Care Boxes",
        description: "Chance for extra pet care loot."
      },
      {
        key: :critical_care,
        label: "Critical Care",
        description: "Care actions can critically improve pet needs."
      }
    ]
  end

  def hero_reset_cost(level)
    if GameConfig.respond_to?(:hero_upgrade_reset_cost)
      GameConfig.hero_upgrade_reset_cost(level)
    else
      multiplier = if GameConfig.const_defined?(:HERO_UPGRADE_RESET_COST_MULTIPLIER)
                     GameConfig::HERO_UPGRADE_RESET_COST_MULTIPLIER
                   else
                     100
                   end
      level.to_i * multiplier
    end
  end
end
