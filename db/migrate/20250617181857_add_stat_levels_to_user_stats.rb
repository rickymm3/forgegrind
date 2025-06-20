class AddStatLevelsToUserStats < ActiveRecord::Migration[8.0]
  def change
    change_table :user_stats do |t|
      t.integer :hp_level,         null: false, default: 1
      t.integer :attack_level,     null: false, default: 1
      t.integer :defense_level,    null: false, default: 1
      t.integer :luck_level,       null: false, default: 1
      t.integer :attunement_level, null: false, default: 1
    end
  end
end
