require "test_helper"

class RecordsControllerTest < ActionDispatch::IntegrationTest
  test "index renders all-time pivot" do
    get records_url
    assert_response :success
  end

  test "index renders year pivot" do
    get records_year_url(2024)
    assert_response :success
  end
end
