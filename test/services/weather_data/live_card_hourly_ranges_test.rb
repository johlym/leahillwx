# frozen_string_literal: true

require "test_helper"

class WeatherData::LiveCardHourlyRangesTest < ActiveSupport::TestCase
  setup do
    # 2:30 pm PT on July 13 — absolute day axis runs 12 am → 11 pm PT.
    @now = Time.utc(2026, 7, 13, 21, 30, 0)
    travel_to @now
  end

  teardown do
    travel_back
  end

  test "returns hourly averages for the local calendar day with overall high/low for the y-axis" do
    create_measurement(hours_ago: 2, humidity: 60, temperature: 20, uvi: 3, rain_rate: 0, wind_speed: 2, gust_speed: 5)
    create_measurement(hours_ago: 2, humidity: 70, temperature: 22, uvi: 5, rain_rate: 1.27, wind_speed: 4, gust_speed: 8)
    create_measurement(hours_ago: 1, humidity: 55, temperature: 18, uvi: 1, rain_rate: 0, wind_speed: 1, gust_speed: 3)
    create_measurement(hours_ago: 0, humidity: 50, temperature: 17, uvi: 0, rain_rate: 0, wind_speed: 0.5, gust_speed: 2)

    Aqi.create!(
      observed_at: (@now - 1.hour).beginning_of_hour,
      pm2_5: 12.0,
      epa_aqi: 51,
      source: "airnow"
    )
    Aqi.create!(
      observed_at: @now.beginning_of_hour,
      pm2_5: 8.0,
      epa_aqi: 33,
      source: "airnow"
    )

    result = WeatherData::LiveCardHourlyRanges.new(now: @now).call

    wind = result[:wind]
    assert_equal 24, wind[:labels].length
    # avg of 2 and 4 m/s → 3 m/s → ~6.71 mph → 7
    assert_includes wind[:values], 7
    assert_includes wind[:markers], 18 # peak gust that hour (8 m/s)
    assert_equal 1, wind[:y_min]  # 0.5 m/s → ~1.12 → 1
    assert_equal 18, wind[:y_max] # 8 m/s gust → ~17.9 → 18

    humidity = result[:humidity]
    assert_equal 24, humidity[:labels].length
    assert_equal "12 am", humidity[:labels].first
    assert_equal "11 pm", humidity[:labels].last
    assert_equal "2 pm", humidity[:labels][14]
    assert_includes humidity[:values], 65 # avg of 60 and 70
    assert_equal 50, humidity[:y_min] # lowest low across hours so far
    assert_equal 70, humidity[:y_max] # highest high across hours so far

    # Future hours of the local day stay blank so the line fills left-to-right.
    assert_nil humidity[:values][15] # 3 pm
    assert_nil humidity[:values][23] # 11 pm
    assert_equal 65, humidity[:values][12] # 12 pm (2 hours before 2 pm)

    rain = result[:rain_rate]
    assert_in_delta 0.03, rain[:values].compact.find { |v| v > 0 }, 0.01 # avg of 0 and 0.05
    assert_equal 0.0, rain[:y_min]
    assert_equal 0.05, rain[:y_max]

    aqi = result[:aqi]
    assert_includes aqi[:values], 51
    assert_includes aqi[:values], 33
    assert_equal 33, aqi[:y_min]
    assert_equal 51, aqi[:y_max]
  end

  test "ignores measurements from the previous local day" do
    # 11 pm PT yesterday is still within a rolling 24h window, but not today.
    create_measurement_at(
      Time.utc(2026, 7, 13, 6, 0, 0), # 11 pm PT July 12
      humidity: 90, temperature: 15, uvi: 0, rain_rate: 0, wind_speed: 1, gust_speed: 2
    )
    create_measurement(hours_ago: 1, humidity: 55, temperature: 18, uvi: 1, rain_rate: 0)
    create_measurement(hours_ago: 0, humidity: 50, temperature: 17, uvi: 0, rain_rate: 0)

    result = WeatherData::LiveCardHourlyRanges.new(now: @now).call
    humidity = result[:humidity]

    refute_includes humidity[:values].compact, 90
    assert_equal 50, humidity[:y_min]
    assert_equal 55, humidity[:y_max]
  end

  test "returns nil series when fewer than two hourly buckets have data" do
    create_measurement(hours_ago: 0, humidity: 50, temperature: 17, uvi: 0, rain_rate: 0)

    result = WeatherData::LiveCardHourlyRanges.new(now: @now).call
    assert_nil result[:humidity]
  end

  private

  def create_measurement(hours_ago:, humidity:, temperature:, uvi:, rain_rate:, wind_speed: 1, gust_speed: 2)
    create_measurement_at(
      @now - hours_ago.hours,
      humidity: humidity,
      temperature: temperature,
      uvi: uvi,
      rain_rate: rain_rate,
      wind_speed: wind_speed,
      gust_speed: gust_speed
    )
  end

  def create_measurement_at(reading_date_time, humidity:, temperature:, uvi:, rain_rate:, wind_speed: 1, gust_speed: 2)
    WeatherMeasurement.create!(
      reading_date_time: reading_date_time,
      barometer_abs: 1013,
      barometer_rel: 1013,
      gust_speed: gust_speed,
      humidity: humidity,
      light: 100,
      rain_day: 0,
      rain_rate: rain_rate,
      temperature: temperature,
      uv: 0,
      uvi: uvi,
      wind_dir: 180,
      wind_speed: wind_speed
    )
  end
end
