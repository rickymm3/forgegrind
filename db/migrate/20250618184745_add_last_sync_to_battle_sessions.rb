class AddLastSyncToBattleSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :battle_sessions, :last_sync_at, :datetime, null: false, default: -> { "NOW()" }

  end
end
