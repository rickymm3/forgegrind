require "test_helper"

class UserPetsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    sign_in @user
    @user_pet = user_pets(:one)
  end

  test "should get index" do
    get user_pets_url
    assert_response :success
  end

  test "releasing a pet awards glow essence and removes the pet" do
    user_stat = user_stats(:one)
    assert user_stat.present?, "user fixture must have stats"

    battle_session = BattleSession.create!(
      user:               @user,
      world:              worlds(:one),
      current_enemy_index: 0,
      player_hp:          10,
      status:             "in_progress",
      enemy_hp:           50,
      last_sync_at:       Time.current,
      ability_cooldowns:  {}
    )
    battle_session.user_pets << @user_pet

    expected_reward = @user_pet.glow_essence_reward

    assert_difference -> { @user.reload.user_pets.count }, -1 do
      assert_difference -> { user_stat.reload.glow_essence }, expected_reward do
        assert_difference -> { battle_session.reload.user_pets.count }, -1 do
          delete user_pet_url(@user_pet)
        end
      end
    end

    assert_redirected_to user_pets_url
    follow_redirect!
    assert_match /#{@user_pet.name} was released/i, @response.body
    refute battle_session.reload.user_pets.exists?(@user_pet.id)
  end
end
