class AddChanceAndBadgesToEvolutionRules < ActiveRecord::Migration[8.0]
  def change
    add_column :evolution_rules, :success_chance_percent, :integer, null: false, default: 100
    add_reference :evolution_rules, :fallback_child_pet, foreign_key: { to_table: :pets }, null: true
    add_column :evolution_rules, :required_badges, :text, array: true, default: [], null: false
  end
end
