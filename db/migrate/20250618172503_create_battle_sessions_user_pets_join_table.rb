class CreateBattleSessionsUserPetsJoinTable < ActiveRecord::Migration[8.0]
  def change
    create_table :battle_sessions_user_pets, id: false do |t|
      t.references :battle_session,
                   null: false,
                   foreign_key: true,
                   index: { name: "index_bs_up_on_bs" }
      t.references :user_pet,
                   null: false,
                   foreign_key: true,
                   index: { name: "index_bs_up_on_up" }
    end
  end
end
