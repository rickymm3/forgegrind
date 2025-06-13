require "test_helper"

class UserPetsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get user_pets_url
    assert_response :success
  end
end
