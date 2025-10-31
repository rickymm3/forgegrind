class AddDiamondRewardToWorlds < ActiveRecord::Migration[8.0]
  def change
    add_column :worlds, :diamond_reward, :integer, null: false, default: 0
  end
end
