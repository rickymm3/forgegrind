class AddCareRequestsToUserPets < ActiveRecord::Migration[7.1]
  def change
    add_column :user_pets, :care_request, :jsonb, default: {}, null: false
    add_column :user_pets, :care_request_cooldown_until, :datetime
  end
end
