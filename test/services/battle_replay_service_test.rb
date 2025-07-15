require "test_helper"

class BattleReplayServiceTest < ActiveSupport::TestCase
  test "replays simple battle" do
    world = World.create!(name: "Test Land", duration: 1, reward_item_type: "none")
    enemy = world.enemies.create!(name: "Slime", hp: 10, attack: 1, defense: 0,
                                  trophy_reward_base: 5, trophy_reward_growth: 0,
                                  boss_bonus_multiplier: 1.0)

    user = User.create!(email: "tester@example.com", password: "secret123")
    stat = user.create_user_stat!(player_level: 1, hp_level: 1, attack_level: 1,
                                  defense_level: 1, luck_level: 1, attunement_level: 0,
                                  trophies: 0, energy: 0, energy_updated_at: Time.current)

    events = [
      { "at" => 0, "type" => "player_tick" },
      { "at" => 1000, "type" => "player_tick" }
    ]

    result = BattleReplayService.new(world: world, user_stat: stat, user_pets: [], events: events).run
    assert_equal :won, result.status
    assert_equal 5, result.trophies
  end
end