class CreateZoneChestDrops < ActiveRecord::Migration[8.0]
  def change
    create_table :zone_chest_drops do |t|
      t.references :world, null: false, foreign_key: true
      t.references :chest_type, null: false, foreign_key: true
      t.integer :weight, null: false, default: 100
      t.timestamps
    end

    add_index :zone_chest_drops, [:world_id, :chest_type_id], unique: true
  end
end
