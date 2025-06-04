class AddEnergyAndAsleepUntilToUserPets < ActiveRecord::Migration[8.0]
  def change
    add_column :user_pets, :energy, :integer, default: 100, null: false
    add_column :user_pets, :asleep_until, :datetime, null: true
  end
end
