class UpdateAbilitiesForTurnBased < ActiveRecord::Migration[8.0]
  def change
    # Remove old tuning columns
    remove_column :abilities, :power,    :integer
    remove_column :abilities, :cost,     :integer
    remove_column :abilities, :cooldown, :integer
    remove_column :abilities, :damage,   :integer

    # Add the handler reference key
    add_column  :abilities, :reference, :string, null: false
    add_index   :abilities, :reference, unique: true
  end
end