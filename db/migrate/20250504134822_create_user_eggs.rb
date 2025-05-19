class CreateUserEggs < ActiveRecord::Migration[8.0]
  def change
    create_table :user_eggs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :egg, null: false, foreign_key: true
      t.boolean :hatched
      t.datetime :hatch_started_at

      t.timestamps
    end
  end
end
