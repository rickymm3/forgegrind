class CreatePets < ActiveRecord::Migration[8.0]
  def change
    create_table :pets do |t|
      t.string :name
      t.string :rarity
      t.integer :power
      t.references :egg, null: false, foreign_key: true

      t.timestamps
    end
  end
end
