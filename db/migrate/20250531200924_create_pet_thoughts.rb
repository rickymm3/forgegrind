class CreatePetThoughts < ActiveRecord::Migration[8.0]
  def change
    create_table :pet_thoughts do |t|
      t.string :thought
      t.float :playfulness_mod
      t.float :affection_mod
      t.float :temperament_mod
      t.float :curiosity_mod
      t.float :confidence_mod

      t.timestamps
    end
  end
end
