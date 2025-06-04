class AddPersonalityStatsToUserPets < ActiveRecord::Migration[8.0]
  def change
    add_column :user_pets, :playfulness, :integer
    add_column :user_pets, :affection, :integer
    add_column :user_pets, :temperament, :integer
    add_column :user_pets, :curiosity, :integer
    add_column :user_pets, :confidence, :integer
  end
end
