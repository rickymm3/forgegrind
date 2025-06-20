class AddEnabledToWorlds < ActiveRecord::Migration[8.0]
  def change
    add_column :worlds, :enabled, :boolean, null: false, default: true
  end
end
