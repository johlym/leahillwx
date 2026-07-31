# frozen_string_literal: true

require "test_helper"

class WeatherData::TodayPeaksTest < ActiveSupport::TestCase
  test "reads day peaks from hourly range y-axis highs" do
    peaks = WeatherData::TodayPeaks.from_hourly_ranges(
      wind: { y_max: 18, y_min: 1 },
      humidity: { y_max: 70, y_min: 50 },
      uvi: { y_max: 5, y_min: 0 },
      rain_rate: { y_max: 0.05, y_min: 0.0 },
      dew_point: { y_max: 55, y_min: 40 }
    )

    assert_equal 18, peaks[:wind_gust_mph]
    assert_equal 70, peaks[:humidity]
    assert_equal 5, peaks[:uvi]
    assert_equal 0.05, peaks[:rain_rate_in]
    assert_equal 55, peaks[:dew_point_f]
  end

  test "returns nil peaks when hourly ranges have no data" do
    peaks = WeatherData::TodayPeaks.from_hourly_ranges(
      wind: { labels: [], values: [] },
      humidity: { labels: [], values: [] }
    )

    assert_nil peaks[:wind_gust_mph]
    assert_nil peaks[:humidity]
    assert_nil peaks[:uvi]
    assert_nil peaks[:rain_rate_in]
    assert_nil peaks[:dew_point_f]
  end

  test "matches LiveCardHourlyRanges highs for today's measurements" do
    now = Time.utc(2026, 7, 13, 21, 30, 0)
    travel_to now

    WeatherMeasurement.create!(
      reading_date_time: now - 20.minutes,
      barometer_abs: 1013.0,
      barometer_rel: 1013.0,
      gust_speed: 8.0,
      humidity: 70,
      light: 1000.0,
      rain_day: 0.0,
      rain_rate: 1.27,
      temperature: 22.0,
      uv: 3,
      uvi: 5.0,
      wind_dir: 180,
      wind_speed: 4.0
    )
    WeatherMeasurement.create!(
      reading_date_time: now,
      barometer_abs: 1013.0,
      barometer_rel: 1013.0,
      gust_speed: 2.0,
      humidity: 50,
      light: 1000.0,
      rain_day: 0.0,
      rain_rate: 0.0,
      temperature: 17.0,
      uv: 0,
      uvi: 0.0,
      wind_dir: 180,
      wind_speed: 0.5
    )

    ranges = WeatherData::LiveCardHourlyRanges.new(now: now).call
    peaks = WeatherData::TodayPeaks.from_hourly_ranges(ranges)

    assert_equal ranges.dig(:wind, :y_max), peaks[:wind_gust_mph]
    assert_equal ranges.dig(:humidity, :y_max), peaks[:humidity]
    assert_equal ranges.dig(:uvi, :y_max), peaks[:uvi]
    assert_equal ranges.dig(:rain_rate, :y_max), peaks[:rain_rate_in]
    assert_equal ranges.dig(:dew_point, :y_max), peaks[:dew_point_f]
    assert_equal 70, peaks[:humidity]
  ensure
    travel_back
  end
end
