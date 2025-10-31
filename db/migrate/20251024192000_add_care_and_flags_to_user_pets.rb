class AddCareAndFlagsToUserPets < ActiveRecord::Migration[8.0]
  def change
    change_table :user_pets, bulk: true do |t|
      t.integer  :hunger,        null: false, default: 70
      t.integer  :hygiene,       null: false, default: 70
      t.integer  :boredom,       null: false, default: 70
      t.integer  :injury_level,  null: false, default: 70
      t.integer  :mood,          null: false, default: 70
      t.datetime :needs_updated_at
      t.jsonb    :state_flags,        null: false, default: {}
      t.jsonb    :evolution_journal,  null: false, default: {}
      t.jsonb    :badges,             null: false, default: []
      t.integer  :care_good_days_count, null: false, default: 0
      t.date     :last_good_day
    end
  end
end
