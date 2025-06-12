class CreateEvolutionRules < ActiveRecord::Migration[8.0]
  def change
    create_table :evolution_rules do |t|
      # point both to pets table
      t.references :parent_pet, null: false, foreign_key: { to_table: :pets }
      t.references :child_pet,  null: false, foreign_key: { to_table: :pets }

      t.integer    :trigger_level,            null: false
      # point to items table
      t.references :required_item,            foreign_key: { to_table: :items }
      t.string     :required_trait
      t.float      :required_trait_threshold
      t.integer    :required_play_count
      t.integer    :required_explorations

      t.timestamps
    end
  end
end
