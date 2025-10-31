class AddLastScoutedAtToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :last_scouted_at, :datetime
    add_index :users, :last_scouted_at
  end
end
