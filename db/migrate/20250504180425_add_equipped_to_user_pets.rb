class AddEquippedToUserPets < ActiveRecord::Migration[8.0]
  def change
    add_column :user_pets, :equipped, :boolean
  end
end
