class AddPartyFieldsToUserExplorations < ActiveRecord::Migration[7.1]
  def change
    change_table :user_explorations, bulk: true do |t|
      t.references :primary_user_pet, foreign_key: { to_table: :user_pets }
      t.jsonb :party_snapshot, null: false, default: {}
      t.jsonb :encounter_schedule, null: false, default: []
      t.datetime :encounters_seeded_at
    end
  end
end
