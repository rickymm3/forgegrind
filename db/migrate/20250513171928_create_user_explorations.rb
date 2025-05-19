class CreateUserExplorations < ActiveRecord::Migration[8.0]
  def change
    create_table :user_explorations do |t|
      t.references :user,  null: false, foreign_key: true
      t.references :world, null: false, foreign_key: true
      t.datetime   :started_at, null: false

      t.timestamps
    end
  end
end
