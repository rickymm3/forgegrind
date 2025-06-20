class RenameRebirthsToPlayerLevel < ActiveRecord::Migration[8.0]
  def change
    rename_column :user_stats, :rebirths, :player_level
  end
end
