class AddHeldUserItemToUserPets < ActiveRecord::Migration[8.0]
  def change
    add_reference :user_pets,
                  :held_user_item,
                  foreign_key: { to_table: :user_items },
                  index: true
  end
end
