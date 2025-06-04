class MakePetThoughtOnUserPetsNotNull < ActiveRecord::Migration[8.0]
  def change
    change_column_null :user_pets, :pet_thought_id, false

  end
end
