class CreateEggs < ActiveRecord::Migration[8.0]
  def change
    create_table :eggs do |t|
      t.string :name
      t.string :cost_currency
      t.integer :cost_amount

      t.timestamps
    end
  end
end
