class ChangeEquippedDefaultOnUserPets < ActiveRecord::Migration[8.0]
  def change
    change_column_default :user_pets, :equipped, from: nil, to: false
  end
end
