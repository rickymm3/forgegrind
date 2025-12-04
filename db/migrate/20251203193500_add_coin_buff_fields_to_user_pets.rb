class AddCoinBuffFieldsToUserPets < ActiveRecord::Migration[7.1]
  def change
    add_column :user_pets, :coin_buff_multiplier, :decimal, precision: 5, scale: 2, default: 0, null: false
    add_column :user_pets, :coin_buff_expires_at, :datetime
  end
end
