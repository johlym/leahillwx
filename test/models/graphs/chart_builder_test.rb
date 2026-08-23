# frozen_string_literal: true

require "test_helper"

class Graphs::ChartBuilderTest < ActiveSupport::TestCase
  setup do
    @report = Report.create!(year: 2024, month: 1)
    @report.entries.create!(
      day: 1,
      mean_temp: 10.0,
      high_temp: 15.0,
      low_temp: 5.0,
      rain: 2.0,
      avg_wind_speed: 3.0,
      high_wind_speed: 8.0,
      mean_pressure: 1012.0,
      high_pressure: 1018.0,
      low_pressure: 1008.0
    )
    @report.entries.create!(
      day: 2,
      mean_temp: 12.0,
      high_temp: 16.0,
      low_temp: 6.0,
      rain: 0.0,
      avg_wind_speed: 2.0,
      high_wind_speed: 5.0,
      mean_pressure: 1010.0,
      high_pressure: 1015.0,
      low_pressure: 1005.0
    )
  end

  test "pressure_chart returns high low and mean series" do
    chart = Graphs::ChartBuilder.new(year: 2024, month: 1).pressure_chart

    assert_equal "line", chart[:type]
    assert_equal [ "1", "2" ], chart[:data][:labels]
    assert_equal [ 1018.0, 1015.0 ], chart[:data][:datasets][0][:data]
    assert_equal [ 1008.0, 1005.0 ], chart[:data][:datasets][1][:data]
    assert_equal [ 1012.0, 1010.0 ], chart[:data][:datasets][2][:data]
    assert_equal " hPa", chart[:options][:yUnit]
  end
end
