class AddEnemyHpToBattleSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :battle_sessions, :enemy_hp, :integer, null: false, default: 0

  end
end
