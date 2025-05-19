class CreateUserPets < ActiveRecord::Migration[8.0]
  def change
    create_table :user_pets do |t|
      t.references :user, null: false, foreign_key: true
      t.references :pet, null: false, foreign_key: true
      t.references :egg, null: false, foreign_key: true
      t.string :name
      t.references :rarity, null: false, foreign_key: true
      t.integer :power

      t.timestamps
    end
  end
end
