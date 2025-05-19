class AddCurrencyAndRarityToEggsAndPets < ActiveRecord::Migration[8.0]
  def change
    add_reference :eggs, :currency, foreign_key: true
    add_reference :pets, :rarity, foreign_key: true
    remove_column :eggs, :cost_currency, :string
    remove_column :pets, :rarity, :string
  end
end
