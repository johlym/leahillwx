require "test_helper"

class AlmanacControllerTest < ActionDispatch::IntegrationTest
  test "index redirects to current month" do
    get almanac_url
    assert_redirected_to almanac_month_path(Date.current.year, Date.current.strftime("%B").downcase)
  end

  test "show renders for a valid month" do
    get almanac_month_url(2024, "january")
    assert_response :success
  end

  test "show returns not found for invalid month" do
    get almanac_month_url(2024, "notamonth")
    assert_response :not_found
  end
end
