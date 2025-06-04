class AddPetThoughtToUserPets < ActiveRecord::Migration[8.0]
  def change
    add_reference :user_pets, :pet_thought, null: true, foreign_key: true
  end
end
