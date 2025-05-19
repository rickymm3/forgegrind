class AddHatchDurationToEggs < ActiveRecord::Migration[8.0]
  def change
    add_column :eggs, :hatch_duration, :integer
  end
end
