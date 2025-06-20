class CreateEnemies < ActiveRecord::Migration[8.0]
  def change
    create_table :enemies do |t|
      t.references :world,  null: false, foreign_key: true, index: true
      t.string     :name,   null: false

      t.integer :hp,                   null: false, default: 0
      t.integer :attack,               null: false, default: 0
      t.integer :defense,              null: false, default: 0

      t.integer :trophy_reward_base,   null: false, default: 0
      t.integer :trophy_reward_growth, null: false, default: 0
      t.float   :boss_bonus_multiplier, null: false, default: 1.0

      t.timestamps
    end
  end
end
