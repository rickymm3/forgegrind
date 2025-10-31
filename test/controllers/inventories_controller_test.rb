require "test_helper"

class InventoriesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: "inventory_tester@example.com", password: "Password123!", password_confirmation: "Password123!")
    sign_in @user
  end

  test "should get inventory" do
    get inventory_url
    assert_response :success
  end
end
