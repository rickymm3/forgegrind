class AddEnabledToEggs < ActiveRecord::Migration[8.0]
  def change
    add_column :eggs, :enabled, :boolean, default: true, null: false
  end
end
