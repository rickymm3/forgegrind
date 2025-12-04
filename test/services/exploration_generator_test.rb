require "test_helper"

class ExplorationGeneratorTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @user = User.create!(email: "explorer@example.com", password: "password123")
    @world = World.create!(
      name: "Test World",
      duration: 600,
      reward_item_type: "item",
      enabled: true
    )
  end

  teardown do
    travel_back
  end

  test "generate respects active exploration slots" do
    2.times do
      @user.user_explorations.create!(world: @world, started_at: 1.hour.ago)
    end

    with_stubbed_mods do
      ExplorationGenerator.new(@user).generate!
    end

    @user.reload
    assert_equal 1, @user.generated_explorations.count
    assert_not_nil @user.last_scouted_at
  end

  test "generate enforces cooldown window" do
    generator = ExplorationGenerator.new(@user)

    with_stubbed_mods { generator.generate! }

    error = assert_raises(ExplorationGenerator::CooldownNotElapsedError) do
      with_stubbed_mods { generator.generate! }
    end
    assert_operator error.remaining_seconds, :>, 0

    travel 11.minutes do
      with_stubbed_mods { generator.generate! }
    end

    assert_equal ExplorationGenerator::DEFAULT_COUNT, @user.reload.generated_explorations.count
  end

  private

  def with_stubbed_mods
    base_sample = [
      "test_base",
      {
        label: "Test Base",
        world_name: @world.name,
        world_key: "test_world",
        default_duration: 600,
        requirements: [],
        rewards: {}
      }
    ]
    empty_sample = [nil, {}]

    ExplorationModLibrary.stub(:sample_base, base_sample) do
      ExplorationModLibrary.stub(:sample_prefix, empty_sample) do
        ExplorationModLibrary.stub(:sample_suffix, empty_sample) do
          yield
        end
      end
    end
  end
end
