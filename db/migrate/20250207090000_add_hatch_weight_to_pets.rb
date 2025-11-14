class AddHatchWeightToPets < ActiveRecord::Migration[8.0]
  def change
    add_column :pets, :hatch_weight, :integer, default: 100, null: false
  end
end
