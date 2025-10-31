class CreateLootEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :loot_entries do |t|
      t.references :loot_table, null: false, foreign_key: true
      t.references :item, null: false, foreign_key: true
      t.integer :weight, null: false, default: 1
      t.integer :qty_min, null: false, default: 1
      t.integer :qty_max, null: false, default: 1
      t.string :rarity, null: false, default: "common"
      t.jsonb :constraints_json, null: false, default: {}
      t.timestamps
    end
  end
end
