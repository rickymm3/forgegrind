class AddUnlockedViaToUserPetAbilities < ActiveRecord::Migration[8.0]
  def change
    add_column :user_pet_abilities, :unlocked_via, :string
  end
end
