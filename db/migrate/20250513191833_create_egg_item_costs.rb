class CreateEggItemCosts < ActiveRecord::Migration[8.0]
  def change
    create_table :egg_item_costs do |t|
      t.references :egg, null: false, foreign_key: true
      t.references :item, null: false, foreign_key: true
      t.integer :quantity

      t.timestamps
    end
  end
end
