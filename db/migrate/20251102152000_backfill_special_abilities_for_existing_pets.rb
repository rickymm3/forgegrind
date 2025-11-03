class BackfillSpecialAbilitiesForExistingPets < ActiveRecord::Migration[7.1]
  def up
    say_with_time "Syncing special ability definitions" do
      PetSpecialAbilityCatalog.sync_definitions!
    end

    say_with_time "Assigning default special abilities to existing pets" do
      PetSpecialAbilityCatalog.backfill_pets!
    end
  end

  def down
    # No automatic rollback – existing records will keep their assigned special abilities.
  end
end
