class CreateBattleSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :battle_sessions do |t|
      t.references :user,  null: false, foreign_key: true
      t.references :world, null: false, foreign_key: true

      t.integer :current_enemy_index, null: false, default: 0
      t.integer :player_hp,           null: false
      t.string  :status,              null: false, default: "in_progress"
      # status values: "in_progress", "won", "lost"

      t.timestamps
    end
  end
end
