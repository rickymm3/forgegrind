class CreateAbilityPermissions < ActiveRecord::Migration[8.0]
  def change
    create_table :ability_permissions do |t|
      t.references :ability,  null: false, foreign_key: true
      t.references :permitted, polymorphic: true, null: false

      t.timestamps
    end

    add_index :ability_permissions, [:permitted_type, :permitted_id], name: "index_permissions_on_permitted"
  end
end
