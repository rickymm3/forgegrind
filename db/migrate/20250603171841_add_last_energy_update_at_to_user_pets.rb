class AddLastEnergyUpdateAtToUserPets < ActiveRecord::Migration[8.0]
  def change
    add_column :user_pets, :last_energy_update_at, :datetime, null: true
  end
end
