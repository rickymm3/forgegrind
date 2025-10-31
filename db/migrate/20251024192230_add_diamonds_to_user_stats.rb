class AddDiamondsToUserStats < ActiveRecord::Migration[8.0]
  def change
    add_column :user_stats, :diamonds, :integer, null: false, default: 0
  end
end
