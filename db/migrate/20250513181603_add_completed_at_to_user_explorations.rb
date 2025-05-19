class AddCompletedAtToUserExplorations < ActiveRecord::Migration[8.0]
  def change
    add_column :user_explorations, :completed_at, :datetime
  end
end
