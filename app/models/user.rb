class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  has_one :user_stat, dependent: :destroy
  has_many :user_eggs, dependent: :destroy
  has_many :user_pets, dependent: :destroy
  has_many :user_explorations, dependent: :destroy
  has_many :user_items, dependent: :destroy
  has_many :user_containers, dependent: :destroy
  has_many :container_open_events, dependent: :destroy
  has_many :battle_sessions, dependent: :destroy
  has_many :user_zone_completions, dependent: :destroy
  has_many :generated_explorations, dependent: :destroy
  has_many :user_notifications, dependent: :destroy

  has_and_belongs_to_many :unlocked_worlds, class_name: 'World', join_table: 'user_worlds'

  after_create :unlock_starter_world

  after_create :build_default_stats
  after_create :give_starter_egg

  CURRENCY_FIELDS = {
    "Trophies" => :trophies,
    "Diamonds" => :diamonds,
    "Glow Essence" => :glow_essence
  }.freeze

  STAT_DEFAULTS = {
    player_level:       1,
    hp_level:           1,
    attack_level:       1,
    defense_level:      1,
    luck_level:         1,
    attunement_level:   1,
    energy:             0,
    trophies:           0,
    glow_essence:       0,
    diamonds:           0
  }.freeze

  def admin?
    self.admin
  end

  def can_afford_egg?(egg)
    stat = ensure_user_stat
    enough_currency = if egg.currency && egg.cost_amount.to_i.positive?
                         currency_field = currency_field_for(egg.currency)
                         currency_field && stat.send(currency_field).to_i >= egg.cost_amount
                       else
                         true
                       end

    enough_currency && egg.egg_item_costs.all? do |cost|
      user_items.joins(:item).where(items: { id: cost.item_id }).sum(:quantity) >= cost.quantity
    end
  end

  def spend_items_for_egg!(egg)
    egg.egg_item_costs.each do |cost|
      user_item = user_items.find_by(item_id: cost.item_id)
  
      raise ActiveRecord::Rollback, "Not enough #{cost.item.name}" if user_item.nil? || user_item.quantity < cost.quantity
  
      user_item.update!(quantity: user_item.quantity - cost.quantity)
    end
  end

  def spend_currency_for_egg!(egg)
    return unless egg.currency && egg.cost_amount.to_i.positive?

    stat = ensure_user_stat
    currency_field = currency_field_for(egg.currency)
    raise ActiveRecord::Rollback, "Unsupported currency" unless currency_field

    current_amount = stat.send(currency_field).to_i
    raise ActiveRecord::Rollback, "Not enough #{egg.currency.name}" if current_amount < egg.cost_amount

    stat.update!(currency_field => current_amount - egg.cost_amount)
  end

  def currency_balance(currency)
    field = currency_field_for(currency)
    return 0 unless field

    ensure_user_stat.send(field).to_i
  end

  private

  def build_default_stats
    create_user_stat!(STAT_DEFAULTS.merge(energy_updated_at: Time.current))
  end

  def ensure_user_stat
    stat = user_stat
    return stat if stat&.valid?

    stat ||= create_user_stat!(STAT_DEFAULTS.merge(energy_updated_at: Time.current))

    # Repair existing stats that may have invalid zeros from legacy data.
    needs_repair = %i[player_level hp_level attack_level defense_level luck_level attunement_level].any? do |attr|
      stat.send(attr).to_i <= 0
    end

    if needs_repair
      updates = STAT_DEFAULTS.slice(:player_level, :hp_level, :attack_level, :defense_level, :luck_level, :attunement_level)
      stat.update!(updates)
    end

    stat.energy_updated_at ||= Time.current
    stat.save! if stat.changed?

    stat
  end
  
  def currency_field_for(currency)
    return unless currency

    CURRENCY_FIELDS[currency.name]
  end
  
  def give_starter_egg
    starter = Egg.find_by(name: "Starter Egg")
    return unless starter
    user_eggs.create!(egg: starter, hatched: false, hatch_started_at: nil)
  end

  def unlock_starter_world
    starter = World.find_by(name: 'Starter Zone')
    unlocked_worlds << starter if starter
  end
  
end
