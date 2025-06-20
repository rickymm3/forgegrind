class CreateUserWorldsJoinTable < ActiveRecord::Migration[8.0]
  def change
    create_table :user_worlds, id: false do |t|
      t.references :user,  null: false, foreign_key: true, index: true
      t.references :world, null: false, foreign_key: true, index: true
    end

    add_index :user_worlds, [:user_id, :world_id], unique: true
  end
end
