class AddAbilityCooldownsToBattleSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :battle_sessions, :ability_cooldowns, :jsonb, null: false, default: {}
  end
end
