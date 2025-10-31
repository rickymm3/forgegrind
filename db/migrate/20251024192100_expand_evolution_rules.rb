class ExpandEvolutionRules < ActiveRecord::Migration[8.0]
  def change
    change_table :evolution_rules, bulk: true do |t|
      t.integer :priority,         null: false, default: 0
      t.integer :window_min_level
      t.integer :window_max_level
      t.string  :window_event
      t.jsonb   :guard_json,       null: false, default: {}
      t.boolean :one_shot,         null: false, default: true
      t.string  :seasonal_tag
      t.text    :notes
    end
  end
end
