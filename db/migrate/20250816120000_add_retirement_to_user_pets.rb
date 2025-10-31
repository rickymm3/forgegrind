class AddRetirementToUserPets < ActiveRecord::Migration[7.1]
  def change
    add_column :user_pets, :retired_at, :datetime
    add_column :user_pets, :retired_reason, :string

    add_reference :user_pets,
                  :predecessor_user_pet,
                  foreign_key: { to_table: :user_pets, on_delete: :nullify }
    add_reference :user_pets,
                  :successor_user_pet,
                  foreign_key: { to_table: :user_pets, on_delete: :nullify }

    add_index :user_pets, :retired_at
  end
end
