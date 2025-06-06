class CreateJoinTablePetsPetTypes < ActiveRecord::Migration[8.0]
  def change
    create_join_table :pets, :pet_types do |t|
      t.index :pet_id
      t.index :pet_type_id
      # t.index [:pet_id, :pet_type_id], unique: true # optional, to enforce uniqueness
    end
  end
end
