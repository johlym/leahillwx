require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @report = Report.create!(
      year: 2024,
      month: 1,
      month_mean_temp: 10.0,
      month_high_temp: 15.0,
      month_high_temp_day: 15,
      month_low_temp: 5.0,
      month_low_temp_day: 1,
      total_heat_degree_days: 100.0,
      total_cool_degree_days: 0.0,
      total_rain: 2.5,
      avg_wind_speed: 5.0,
      month_high_wind_speed: 15.0,
      month_high_wind_day: 10,
      dominant_wind_dir: 180
    )
    @report.entries.create!(day: 15, mean_temp: 50.0, high_temp: 60.0, low_temp: 40.0)
  end

  test "should redirect to latest report from index when reports exist" do
    get reports_url
    assert_redirected_to report_path(2024, "january")
  end

  test "should show message when no reports exist" do
    Report.destroy_all
    get reports_url
    assert_response :success
    assert_select "div.message"
  end

  test "should get available reports as json" do
    get available_reports_url, as: :json
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal({ "2024" => [ "january" ] }, json)
  end

  test "should show report" do
    get report_url(2024, "january")
    assert_response :success
    assert_select "h1 small", text: "for January 2024"
  end

  test "should return 404 for invalid month name" do
    get report_url(2024, "invalid")
    assert_response :not_found
  end

  test "should return 404 for non-existent report" do
    get report_url(2023, "december")
    assert_response :not_found
  end

  test "should render text format" do
    get report_url(2024, "january", format: :text)
    assert_response :success
    assert_match(/MONTHLY CLIMATOLOGICAL SUMMARY/, response.body)
  end
end
