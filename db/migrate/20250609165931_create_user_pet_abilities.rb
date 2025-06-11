class CreateUserPetAbilities < ActiveRecord::Migration[8.0]
  def change
    create_table :user_pet_abilities do |t|
      t.references :user_pet, null: false, foreign_key: true
      t.references :ability,  null: false, foreign_key: true

      t.timestamps
    end

    add_index :user_pet_abilities, [:user_pet_id, :ability_id], unique: true, name: "index_user_pet_abilities_on_user_pet_and_ability"
  end
end
