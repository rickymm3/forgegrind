class CreateLootTables < ActiveRecord::Migration[8.0]
  def change
    create_table :loot_tables do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.integer :rolls_min, null: false, default: 1
      t.integer :rolls_max, null: false, default: 1
      t.jsonb :pity_config_json, null: false, default: {}
      t.timestamps
    end

    add_index :loot_tables, :key, unique: true
  end
end
