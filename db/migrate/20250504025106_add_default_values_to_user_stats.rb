class AddDefaultValuesToUserStats < ActiveRecord::Migration[8.0]
  def change
    change_column_default :user_stats, :energy, from: nil, to: 0
    change_column_default :user_stats, :trophies, from: nil, to: 0
    change_column_default :user_stats, :rebirths, from: nil, to: 0
  end
end
