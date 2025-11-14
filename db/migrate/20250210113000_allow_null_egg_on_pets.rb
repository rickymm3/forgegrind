class AllowNullEggOnPets < ActiveRecord::Migration[8.0]
  def change
    change_column_null :pets, :egg_id, true
  end
end
