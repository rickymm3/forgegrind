class CreateCurrencies < ActiveRecord::Migration[8.0]
  def change
    create_table :currencies do |t|
      t.string :name
      t.string :symbol

      t.timestamps
    end
  end
end
