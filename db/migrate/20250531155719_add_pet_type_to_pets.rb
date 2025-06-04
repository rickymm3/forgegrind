class AddPetTypeToPets < ActiveRecord::Migration[8.0]
  def change
    add_reference :pets, :pet_type, foreign_key: true, index: true
  end
end
