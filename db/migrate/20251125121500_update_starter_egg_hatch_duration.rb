class UpdateStarterEggHatchDuration < ActiveRecord::Migration[8.0]
  def up
    Egg.where(name: "Starter Egg").update_all(hatch_duration: 15)
  end

  def down
    Egg.where(name: "Starter Egg").update_all(hatch_duration: 5)
  end
end
