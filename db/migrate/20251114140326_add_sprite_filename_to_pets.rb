class AddSpriteFilenameToPets < ActiveRecord::Migration[7.1]
  def change
    add_column :pets, :sprite_filename, :string
  end
end
