require "test_helper"

class NurseryControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get nursery_index_url
    assert_response :success
  end
end
