class AddExplorationTraitsAndCompletions < ActiveRecord::Migration[8.0]
  def change
    change_table :worlds, bulk: true do |t|
      t.boolean :upgraded_on_clear, default: true, null: false
      t.jsonb   :special_traits, default: [], null: false
      t.text    :required_pet_abilities, array: true, default: [], null: false
      t.string  :drop_table_override_key
      t.text    :upgrade_trait_keys, array: true, default: [], null: false
      t.text    :upgrade_required_pet_abilities, array: true, default: [], null: false
      t.string  :upgrade_drop_table_override_key
      t.boolean :rotation_active, default: true, null: false
      t.integer :rotation_weight, default: 1, null: false
      t.datetime :rotation_starts_at
      t.datetime :rotation_ends_at
    end

    create_table :user_zone_completions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :world, null: false, foreign_key: true
      t.integer :times_cleared, default: 0, null: false
      t.datetime :last_completed_at

      t.timestamps
    end

    add_index :user_zone_completions, [:user_id, :world_id], unique: true
  end
end
