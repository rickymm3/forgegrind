class Currency < ApplicationRecord
  has_many :eggs

  validates :name, presence: true, uniqueness: true

  DEFAULT_KEYS = {
    coins: "Coins",
    diamonds: "Diamonds",
    glow_essence: "Glow Essence"
  }.freeze

  def self.find_by_key(key)
    return unless key

    name = DEFAULT_KEYS[key.to_sym] || key.to_s
    find_by(name: name)
  end

  def self.lookup(key_or_name)
    case key_or_name
    when Currency
      key_or_name
    when String
      find_by(name: key_or_name)
    when Symbol
      find_by_key(key_or_name)
    when Integer
      find_by(id: key_or_name)
    end
  end

  def self.lookup!(key_or_name)
    lookup(key_or_name) || raise(ActiveRecord::RecordNotFound, "Currency #{key_or_name} not found")
  end
end
