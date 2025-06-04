class AddLastInteractedAtToUserPets < ActiveRecord::Migration[8.0]
  def change
    add_column :user_pets, :last_interacted_at, :datetime
  end
end
