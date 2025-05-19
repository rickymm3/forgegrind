class CreateItems < ActiveRecord::Migration[8.0]
  def change
    create_table :items do |t|
      t.string :name,      null: false
      t.string :item_type, null: false

      t.timestamps
    end
  end
end
