class AddActiveSlotToUserPets < ActiveRecord::Migration[8.0]
  def change
    add_column :user_pets, :active_slot, :integer
    add_index :user_pets, [:user_id, :active_slot], unique: true, where: "active_slot IS NOT NULL"
  end
end
