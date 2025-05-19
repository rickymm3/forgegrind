class CreateWorlds < ActiveRecord::Migration[8.0]
  def change
    create_table :worlds do |t|
      t.string  :name,               null: false
      t.integer :duration,           null: false, default: 0
      t.string  :reward_item_type,   null: false

      t.timestamps
    end
  end
end
