# frozen_string_literal: true

class AddCareTrackersToUserPets < ActiveRecord::Migration[7.1]
  def change
    add_column :user_pets, :care_trackers, :jsonb, null: false, default: {}
  end
end
