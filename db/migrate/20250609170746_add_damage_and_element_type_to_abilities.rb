class AddDamageAndElementTypeToAbilities < ActiveRecord::Migration[8.0]
  def change
    add_column :abilities, :damage,       :integer, null: false, default: 0
    add_column :abilities, :element_type, :string
  end
end
