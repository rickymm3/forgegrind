class AddSlotAndCooldownToGeneratedExplorations < ActiveRecord::Migration[7.1]
  class MigrationGeneratedExploration < ApplicationRecord
    self.table_name = "generated_explorations"
  end

  MAX_SLOTS = 3

  def up
    add_column :generated_explorations, :slot_index, :integer
    add_column :generated_explorations, :cooldown_ends_at, :datetime
    add_index :generated_explorations,
              [:user_id, :slot_index],
              unique: true,
              where: "slot_index IS NOT NULL",
              name: "index_generated_explorations_on_user_and_slot"

    say_with_time "Assigning slot indexes to existing generated explorations" do
      MigrationGeneratedExploration.reset_column_information
      MigrationGeneratedExploration.where(slot_index: nil).group_by(&:user_id).each do |_user_id, records|
        records.sort_by!(&:created_at)
        records.first(MAX_SLOTS).each_with_index do |generated, index|
          generated.update_columns(slot_index: index + 1)
        end
      end
    end
  end

  def down
    remove_index :generated_explorations, name: "index_generated_explorations_on_user_and_slot"
    remove_column :generated_explorations, :cooldown_ends_at
    remove_column :generated_explorations, :slot_index
  end
end
