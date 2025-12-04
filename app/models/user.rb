class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  has_one :user_stat, dependent: :destroy
  has_many :user_currencies, dependent: :destroy
  has_many :currencies, through: :user_currencies
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
  after_create :initialize_currency_wallets

  LEGACY_CURRENCY_FIELDS = {
    "Coins" => :trophies,
    "Diamonds" => :diamonds,
    "Glow Essence" => :glow_essence
  }.freeze

  STAT_DEFAULTS = {
    player_level:       1,
    player_experience:  0,
    hp_level:           1,
    attack_level:       1,
    defense_level:      1,
    luck_level:         1,
    attunement_level:   1,
    energy:             0
  }.freeze
  ACTIVE_PET_SLOT_COUNT = 3

  def admin?
    self.admin
  end

  def player_level
    ensure_user_stat.player_level.to_i
  end

  def player_experience
    ensure_user_stat.player_experience.to_i
  end

  def grant_player_experience!(amount)
    ensure_user_stat.grant_player_experience!(amount)
  end

  def can_afford_egg?(egg)
    enough_currency = if egg.currency && egg.cost_amount.to_i.positive?
                        currency_balance(egg.currency) >= egg.cost_amount
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

    debit_currency!(egg.currency, egg.cost_amount)
  end

  def currency_balance(currency)
    currency_wallet_for(currency)&.balance.to_i
  rescue ActiveRecord::RecordNotFound
    0
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

  def active_pet_slots
    slots = Array.new(ACTIVE_PET_SLOT_COUNT)
    user_pets.where.not(active_slot: nil).each do |pet|
      next if pet.active_slot.nil?
      index = pet.active_slot.to_i
      next unless index.between?(0, ACTIVE_PET_SLOT_COUNT - 1)

      slots[index] = pet
    end
    slots
  end

  def first_available_pet_slot
    used = user_pets.where.not(active_slot: nil).pluck(:active_slot).compact
    (0...ACTIVE_PET_SLOT_COUNT).detect { |idx| !used.include?(idx) }
  end

  def assign_pet_to_slot!(slot, user_pet)
    slot = slot.to_i
    raise ArgumentError, "Invalid slot" unless slot.between?(0, ACTIVE_PET_SLOT_COUNT - 1)

    UserPet.transaction do
      user_pets.where(active_slot: slot).update_all(active_slot: nil, equipped: false)
      if user_pet
        raise ActiveRecord::RecordNotFound unless user_pet.user_id == id
        user_pet.update!(active_slot: slot)
      end
    end
  end

  def clear_pet_slot!(slot)
    assign_pet_to_slot!(slot, nil)
  end

  def auto_assign_active_slot!(user_pet)
    slot = first_available_pet_slot
    if slot.nil?
      user_pet.update!(active_slot: nil)
    else
      assign_pet_to_slot!(slot, user_pet)
    end
  end

  def currency_wallet_for(currency, create: true)
    currency = Currency.lookup(currency)
    raise ActiveRecord::RecordNotFound, "Currency not found" unless currency

    wallet = user_currencies.find_by(currency_id: currency.id)
    if wallet.nil? && create
      wallet = user_currencies.create!(currency: currency, balance: legacy_currency_balance(currency))
    end
    wallet
  end

  def legacy_currency_balance(currency)
    field = LEGACY_CURRENCY_FIELDS[currency.name]
    return 0 unless field

    ensure_user_stat.public_send(field).to_i
  rescue StandardError
    0
  end

  def ensure_currency_wallets!(currencies)
    Array(currencies).each do |currency|
      currency_wallet_for(currency)
    end
  end

  def credit_currency!(currency, amount)
    wallet = currency_wallet_for(currency)
    wallet&.credit!(amount)
  end

  def debit_currency!(currency, amount)
    wallet = currency_wallet_for(currency)
    wallet&.debit!(amount)
  end
  
  private

  def build_default_stats
    create_user_stat!(STAT_DEFAULTS.merge(energy_updated_at: Time.current))
  end

  def initialize_currency_wallets
    ensure_currency_wallets!(Currency.all)
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
