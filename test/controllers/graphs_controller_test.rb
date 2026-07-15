require "test_helper"

class GraphsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get graphs_url
    assert_response :success
  end

  test "show renders charts for an existing report" do
    report = Report.create!(year: 2024, month: 1)
    ReportEntry.create!(
      report: report,
      day: 1,
      hour: nil,
      high_temp: 10.0,
      low_temp: 2.0,
      mean_temp: 6.0,
      rain: 1.0,
      avg_wind_speed: 1.0,
      high_wind_speed: 2.0
    )

    get graph_url(2024, "january")
    assert_response :success
  end

  test "show returns not found for invalid month" do
    get graph_url(2024, "notamonth")
    assert_response :not_found
  end
end
