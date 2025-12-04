class BackfillRarityCoinCaps < ActiveRecord::Migration[7.1]
  RARITY_CAPS = {
    "common" => 500,
    "uncommon" => 600,
    "rare" => 750,
    "epic" => 900,
    "legendary" => 1100
  }.freeze

  def up
    say_with_time "Backfilling coin_daily_cap based on rarity" do
      UserPet.includes(:rarity).find_each do |pet|
        name = pet.rarity&.name.to_s.downcase
        cap = RARITY_CAPS[name] || pet.coin_daily_cap.to_i
        next if cap <= 0 || cap == pet.coin_daily_cap.to_i

        pet.update_columns(coin_daily_cap: cap)
      end
    end
  end

  def down
    # No-op: keep computed caps
  end
end
