class CreateJoinTableWorldsPetTypes < ActiveRecord::Migration[8.0]
  def change
    create_join_table :worlds, :pet_types do |t|
      t.index :world_id
      t.index :pet_type_id
      # t.index [:world_id, :pet_type_id], unique: true # optional
    end
  end
end
