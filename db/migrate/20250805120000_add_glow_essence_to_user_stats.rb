class AddGlowEssenceToUserStats < ActiveRecord::Migration[8.0]
  def change
    add_column :user_stats, :glow_essence, :integer, null: false, default: 0
  end
end
