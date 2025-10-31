class CreateGeneratedExplorations < ActiveRecord::Migration[8.0]
  def change
    create_table :generated_explorations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :world, null: false, foreign_key: true
      t.string :base_key, null: false
      t.string :prefix_key
      t.string :suffix_key
      t.string :name, null: false
      t.jsonb :requirements, null: false, default: []
      t.jsonb :reward_config, null: false, default: {}
      t.jsonb :metadata, null: false, default: {}
      t.integer :duration_seconds, null: false
      t.datetime :scouted_at, null: false
      t.datetime :expires_at
      t.datetime :consumed_at

      t.timestamps
    end

    add_index :generated_explorations, [:user_id, :consumed_at]

    change_table :user_explorations, bulk: true do |t|
      t.references :generated_exploration, foreign_key: true
    end
  end
end
