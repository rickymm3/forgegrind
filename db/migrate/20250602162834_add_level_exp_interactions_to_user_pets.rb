class AddLevelExpInteractionsToUserPets < ActiveRecord::Migration[8.0]
  def change
    add_column :user_pets, :level,                  :integer, default: 1, null: false
    add_column :user_pets, :exp,                    :integer, default: 0, null: false
    add_column :user_pets, :interactions_remaining, :integer, default: 5, null: false
  end
end
