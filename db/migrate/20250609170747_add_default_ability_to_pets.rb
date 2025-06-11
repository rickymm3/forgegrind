class AddDefaultAbilityToPets < ActiveRecord::Migration[8.0]
  def change
    add_reference :pets, :default_ability, foreign_key: { to_table: :abilities }
  end
end
