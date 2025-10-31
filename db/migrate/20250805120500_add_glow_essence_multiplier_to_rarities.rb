class AddGlowEssenceMultiplierToRarities < ActiveRecord::Migration[8.0]
  def change
    add_column :rarities, :glow_essence_multiplier, :integer, null: false, default: 1
  end
end
