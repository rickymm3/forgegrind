class CreateUserCurrencies < ActiveRecord::Migration[8.0]
  class MigrationCurrency < ApplicationRecord
    self.table_name = "currencies"
  end

  class MigrationUserStat < ApplicationRecord
    self.table_name = "user_stats"
    belongs_to :user, class_name: "MigrationUser", foreign_key: :user_id
  end

  class MigrationUser < ApplicationRecord
    self.table_name = "users"
    has_one :user_stat, class_name: "MigrationUserStat", foreign_key: :user_id
    has_many :user_currencies, class_name: "MigrationUserCurrency", foreign_key: :user_id
  end

  class MigrationUserCurrency < ApplicationRecord
    self.table_name = "user_currencies"
    belongs_to :user, class_name: "MigrationUser", foreign_key: :user_id
    belongs_to :currency, class_name: "MigrationCurrency", foreign_key: :currency_id
  end

  DEFAULT_CURRENCY_NAMES = {
    coins: "Coins",
    diamonds: "Diamonds",
    glow_essence: "Glow Essence"
  }.freeze

  def up
    create_table :user_currencies do |t|
      t.references :user, null: false, foreign_key: true
      t.references :currency, null: false, foreign_key: true
      t.bigint :balance, null: false, default: 0
      t.timestamps
    end

    add_index :user_currencies, [:user_id, :currency_id], unique: true

    backfill_from_user_stats
  end

  def down
    drop_table :user_currencies
  end

  private

  def backfill_from_user_stats
    currency_lookup = DEFAULT_CURRENCY_NAMES.values.index_with do |name|
      MigrationCurrency.find_by(name: name)
    end.compact

    return if currency_lookup.empty?

    say_with_time "Backfilling user_currencies from user_stats" do
      MigrationUser.includes(:user_stat).find_each do |user|
        stat = user.user_stat
        next unless stat

        [
          ["Coins", stat.trophies],
          ["Diamonds", stat.diamonds],
          ["Glow Essence", stat.glow_essence]
        ].each do |name, amount|
          currency = currency_lookup[name]
          next unless currency

          wallet = user.user_currencies.find_or_initialize_by(currency_id: currency.id)
          wallet.balance = amount.to_i if wallet.new_record? || wallet.balance.nil?
          wallet.save!
        end
      end
    end
  end
end
