class RemovePetTypeIdFromPets < ActiveRecord::Migration[8.0]
  def change
    remove_reference :pets, :pet_type, index: true, foreign_key: true
  end
end
