class Jointableexplorationuserpets < ActiveRecord::Migration[8.0]
  def change
    create_join_table :user_explorations, :user_pets do |t|
      t.index [:user_exploration_id, :user_pet_id], name: "index_explorations_pets_on_ids"
      t.index [:user_pet_id, :user_exploration_id], name: "index_pets_explorations_on_ids"
    end
  end
end
