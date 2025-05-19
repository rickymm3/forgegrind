require "test_helper"

class ExplorationsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get explorations_index_url
    assert_response :success
  end
end
