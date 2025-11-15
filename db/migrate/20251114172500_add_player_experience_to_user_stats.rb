class AddPlayerExperienceToUserStats < ActiveRecord::Migration[7.1]
  def change
    add_column :user_stats, :player_experience, :integer, null: false, default: 0
  end
end
