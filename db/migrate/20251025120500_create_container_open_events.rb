class CreateContainerOpenEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :container_open_events do |t|
      t.references :user, null: false, foreign_key: true
      t.references :chest_type, null: false, foreign_key: true
      t.integer :opened_qty, null: false, default: 0
      t.jsonb :rewards_json, null: false, default: []
      t.integer :latency_ms
      t.string :client_version
      t.string :request_uuid, null: false
      t.timestamps
    end

    add_index :container_open_events, :request_uuid, unique: true
    add_index :container_open_events, [:user_id, :chest_type_id]
  end
end
