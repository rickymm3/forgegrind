class AddEnergyUpdatedAtToUserStats < ActiveRecord::Migration[8.0]
  def change
    add_column :user_stats, :energy_updated_at, :datetime
  end
end
