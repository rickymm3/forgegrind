class AddEncounterStateToUserExplorations < ActiveRecord::Migration[7.1]
  def change
    change_table :user_explorations, bulk: true do |t|
      t.jsonb :active_encounter, null: false, default: {}
      t.datetime :active_encounter_started_at
      t.datetime :active_encounter_expires_at
    end
  end
end
