class CreateSpecialAbilities < ActiveRecord::Migration[7.1]
  def change
    create_table :special_abilities do |t|
      t.string :reference, null: false
      t.string :name, null: false
      t.string :tagline
      t.text :description
      t.jsonb :encounter_tags, null: false, default: []
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :special_abilities, :reference, unique: true

    change_table :pets, bulk: true do |t|
      t.references :special_ability, foreign_key: { to_table: :special_abilities }
    end
  end
end
