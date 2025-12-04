class AddThoughtTrackingToUserPets < ActiveRecord::Migration[8.0]
  def change
    add_column :user_pets, :thought_expires_at, :datetime
    add_column :user_pets, :thought_suppressed, :boolean, default: false, null: false

    add_index :user_pets, :thought_expires_at

    change_column_null :user_pets, :pet_thought_id, true
  end
end
