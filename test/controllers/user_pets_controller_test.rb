require "test_helper"

class UserPetsControllerTest < ActionDispatch::IntegrationTest
  test "should get equip" do
    get user_pets_equip_url
    assert_response :success
  end

  test "should get unequip" do
    get user_pets_unequip_url
    assert_response :success
  end
end
