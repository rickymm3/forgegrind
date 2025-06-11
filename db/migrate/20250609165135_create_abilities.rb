class CreateAbilities < ActiveRecord::Migration[8.0]
  def change
    create_table :abilities do |t|
      t.string  :name,        null: false
      t.text    :description
      t.integer :power
      t.integer :cost
      t.integer :cooldown

      t.timestamps
    end
  end
end
