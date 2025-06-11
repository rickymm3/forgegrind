class CreateAbilityEffects < ActiveRecord::Migration[8.0]
  def change
    create_table :ability_effects do |t|
      t.references :ability, null: false, foreign_key: true
      t.references :effect,  null: false, foreign_key: true
      t.integer    :magnitude, null: false, default: 0
      t.integer    :duration,  null: false, default: 0  # e.g. seconds or turns

      t.timestamps
    end

    add_index :ability_effects, [:ability_id, :effect_id], unique: true, name: "index_ability_effects_on_ability_and_effect"
  end
end
