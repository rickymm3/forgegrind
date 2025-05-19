class CreateUserStats < ActiveRecord::Migration[8.0]
  def change
    create_table :user_stats do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :energy
      t.integer :trophies
      t.integer :rebirths

      t.timestamps
    end
  end
end
