class AddBattleStatsToPets < ActiveRecord::Migration[8.0]
  def change
    add_column :pets, :hp,     :integer, default: 5, null: false
    add_column :pets, :atk,    :integer, default: 5, null: false
    add_column :pets, :def,    :integer, default: 5, null: false
    add_column :pets, :sp_atk, :integer, default: 5, null: false
    add_column :pets, :sp_def, :integer, default: 5, null: false
    add_column :pets, :speed,  :integer, default: 5, null: false
  end
end
