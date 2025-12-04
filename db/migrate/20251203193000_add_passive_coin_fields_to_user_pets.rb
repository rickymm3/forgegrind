class AddPassiveCoinFieldsToUserPets < ActiveRecord::Migration[7.1]
  def change
    add_column :user_pets, :last_coin_tick_at, :datetime
    add_column :user_pets, :coin_earned_today, :integer, default: 0, null: false
    add_column :user_pets, :coin_daily_cap, :integer, default: 500, null: false
  end
end
