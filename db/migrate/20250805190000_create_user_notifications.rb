class CreateUserNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :user_notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.string :category, null: false
      t.string :title, null: false
      t.text :body
      t.string :action_path
      t.jsonb :metadata, null: false, default: {}
      t.datetime :read_at

      t.timestamps
    end

    add_index :user_notifications, [:user_id, :read_at]
    add_index :user_notifications, [:user_id, :category]
  end
end
