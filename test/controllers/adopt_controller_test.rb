require "test_helper"

class AdoptControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get adopt_index_url
    assert_response :success
  end
end
