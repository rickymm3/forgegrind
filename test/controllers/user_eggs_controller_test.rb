require "test_helper"

class UserEggsControllerTest < ActionDispatch::IntegrationTest
  test "should get incubate" do
    get user_eggs_incubate_url
    assert_response :success
  end
end
