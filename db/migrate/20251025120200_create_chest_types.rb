class CreateChestTypes < ActiveRecord::Migration[8.0]
  def change
    create_table :chest_types do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.string :icon, null: false
      t.references :default_loot_table, null: false, foreign_key: { to_table: :loot_tables }
      t.boolean :open_batch_allowed, default: false, null: false
      t.integer :min_level, default: 1, null: false
      t.boolean :visible, default: true, null: false
      t.timestamps
    end

    add_index :chest_types, :key, unique: true
  end
end
