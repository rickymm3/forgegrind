class AddHeroUpgradesToUserStats < ActiveRecord::Migration[7.1]
  def change
    change_table :user_stats, bulk: true do |t|
      t.integer :hatchers_luck_level, default: 0, null: false
      t.integer :swift_expeditions_level, default: 0, null: false
      t.integer :overflowing_care_boxes_level, default: 0, null: false
      t.integer :critical_care_level, default: 0, null: false
    end
  end
end
