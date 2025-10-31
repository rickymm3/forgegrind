class AllowNullTriggerLevelOnEvolutionRules < ActiveRecord::Migration[8.0]
  def change
    change_column_null :evolution_rules, :trigger_level, true
  end
end
