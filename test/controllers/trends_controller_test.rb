require "test_helper"

class TrendsControllerTest < ActionDispatch::IntegrationTest
  test "index renders" do
    get trends_url
    assert_response :success
  end

  test "show renders for a year" do
    get trends_year_url(2024)
    assert_response :success
  end
end
