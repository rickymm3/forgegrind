class AddSegmentsToExplorations < ActiveRecord::Migration[7.1]
  def change
    change_table :generated_explorations, bulk: true do |t|
      t.jsonb :segment_definitions, null: false, default: []
    end

    change_table :user_explorations, bulk: true do |t|
      t.jsonb :segment_progress, null: false, default: []
      t.integer :current_segment_index, null: false, default: 0
      t.datetime :segment_started_at
    end
  end
end
