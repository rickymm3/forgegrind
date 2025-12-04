class EnsureCoinCurrency < ActiveRecord::Migration[8.0]
  class MigrationCurrency < ApplicationRecord
    self.table_name = "currencies"
  end

  class MigrationEgg < ApplicationRecord
    self.table_name = "eggs"
    belongs_to :currency, class_name: "EnsureCoinCurrency::MigrationCurrency", optional: true
  end

  def up
    coins = MigrationCurrency.find_or_create_by!(name: "Coins") do |c|
      c.symbol = "🪙"
    end

    # Rename any legacy "Trophies" currency rows to "Coins"
    MigrationCurrency.where(name: "Trophies").find_each do |currency|
      currency.update!(name: "Coins", symbol: currency.symbol.presence || "🪙")
    end

    # Point any eggs still using a "Trophies" currency to Coins
    MigrationEgg.includes(:currency).find_each do |egg|
      next unless egg.currency&.name.to_s.casecmp("Trophies").zero?

      egg.update!(currency_id: coins.id)
    end
  end

  def down
    # no-op: we don't want to restore legacy "Trophies" naming
  end
end
