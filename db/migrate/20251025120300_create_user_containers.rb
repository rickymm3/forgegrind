class CreateUserContainers < ActiveRecord::Migration[8.0]
  def change
    create_table :user_containers do |t|
      t.references :user, null: false, foreign_key: true
      t.references :chest_type, null: false, foreign_key: true
      t.integer :count, null: false, default: 0
      t.string :acquired_source, null: false, default: "unknown"
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :user_containers, [:user_id, :chest_type_id], unique: true
  end
end
