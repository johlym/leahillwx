# frozen_string_literal: true

require "test_helper"

class Records::MeasurementScopeTest < ActiveSupport::TestCase
  test "yearly scope uses Pacific calendar bounds near New Year UTC" do
    # 2025-12-31 4pm Pacific == 2026-01-01 00:00 UTC
    late_pacific_2025 = Time.find_zone!("America/Los_Angeles").local(2025, 12, 31, 16, 0, 0)
    early_pacific_2026 = Time.find_zone!("America/Los_Angeles").local(2026, 1, 1, 1, 0, 0)

    late = WeatherMeasurement.create!(
      reading_date_time: late_pacific_2025,
      barometer_abs: 1013, barometer_rel: 1015, gust_speed: 1, light: 0,
      humidity: 50, temperature: 10, rain_day: 0, rain_rate: 0, uv: 0, uvi: 0,
      wind_dir: 90, wind_speed: 1
    )
    early = WeatherMeasurement.create!(
      reading_date_time: early_pacific_2026,
      barometer_abs: 1013, barometer_rel: 1015, gust_speed: 1, light: 0,
      humidity: 50, temperature: 10, rain_day: 0, rain_rate: 0, uv: 0, uvi: 0,
      wind_dir: 90, wind_speed: 1
    )

    scoped_2025 = Records::MeasurementScope.new(scope: "yearly", year: 2025).resolve
    scoped_2026 = Records::MeasurementScope.new(scope: "yearly", year: 2026).resolve

    assert_includes scoped_2025, late
    assert_not_includes scoped_2025, early
    assert_includes scoped_2026, early
    assert_not_includes scoped_2026, late
  end
end
