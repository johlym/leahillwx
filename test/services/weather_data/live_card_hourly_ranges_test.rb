# frozen_string_literal: true

require "test_helper"

class WeatherData::LiveCardHourlyRangesTest < ActiveSupport::TestCase
  setup do
    # 2:30 pm PT on July 13 — absolute day axis runs 12:00 am → 11:50 pm PT
    # in 10-minute buckets (144 points).
    @now = Time.utc(2026, 7, 13, 21, 30, 0)
    travel_to @now
  end

  teardown do
    travel_back
  end

  test "returns 10-minute averages for the local calendar day with overall high/low for the y-axis" do
    create_measurement(minutes_ago: 20, humidity: 60, temperature: 20, uvi: 3, rain_rate: 0, wind_speed: 2, gust_speed: 5)
    create_measurement_at(
      @now - 20.minutes + 30.seconds,
      humidity: 70, temperature: 22, uvi: 5, rain_rate: 1.27, wind_speed: 4, gust_speed: 8
    )
    create_measurement(minutes_ago: 10, humidity: 55, temperature: 18, uvi: 1, rain_rate: 0, wind_speed: 1, gust_speed: 3)
    create_measurement(minutes_ago: 0, humidity: 50, temperature: 17, uvi: 0, rain_rate: 0, wind_speed: 0.5, gust_speed: 2)

    Aqi.create!(
      observed_at: (@now - 10.minutes),
      pm2_5: 12.0,
      epa_aqi: 51,
      source: "airnow"
    )
    Aqi.create!(
      observed_at: @now,
      pm2_5: 8.0,
      epa_aqi: 33,
      source: "airnow"
    )

    result = WeatherData::LiveCardHourlyRanges.new(now: @now).call

    wind = result[:wind]
    assert_equal 144, wind[:labels].length
    # avg of 2 and 4 m/s → 3 m/s → ~6.71 mph → 7
    assert_includes wind[:values], 7
    assert_includes wind[:markers], 18 # peak gust that bucket (8 m/s)
    assert_equal 1, wind[:y_min]  # 0.5 m/s → ~1.12 → 1
    assert_equal 18, wind[:y_max] # 8 m/s gust → ~17.9 → 18

    humidity = result[:humidity]
    assert_equal 144, humidity[:labels].length
    assert_equal "12:00 am", humidity[:labels].first
    assert_equal "11:50 pm", humidity[:labels].last
    # 2:30 pm is bucket index 14*6 + 3 = 87
    assert_equal "2:30 pm", humidity[:labels][87]
    assert_includes humidity[:values], 65 # avg of 60 and 70
    assert_equal 50, humidity[:y_min]
    assert_equal 70, humidity[:y_max]

    # Future buckets of the local day stay blank so the line fills left-to-right.
    assert_nil humidity[:values][88] # 2:40 pm
    assert_nil humidity[:values][143] # 11:50 pm
    assert_equal 65, humidity[:values][85] # 2:10 pm bucket? 20 min ago = 2:10 pm → index 85
    # minutes_ago 20 from 2:30 = 2:10 → bucket 2:10 = 14*6 + 1 = 85

    rain = result[:rain_rate]
    assert_in_delta 0.03, rain[:values].compact.find { |v| v > 0 }, 0.01
    assert_equal 0.0, rain[:y_min]
    assert_equal 0.05, rain[:y_max]

    aqi = result[:aqi]
    assert_includes aqi[:values], 51
    assert_includes aqi[:values], 33
    assert_equal 33, aqi[:y_min]
    assert_equal 51, aqi[:y_max]
  end

  test "ignores measurements from the previous local day" do
    create_measurement_at(
      Time.utc(2026, 7, 13, 6, 0, 0), # 11 pm PT July 12
      humidity: 90, temperature: 15, uvi: 0, rain_rate: 0, wind_speed: 1, gust_speed: 2
    )
    create_measurement(minutes_ago: 10, humidity: 55, temperature: 18, uvi: 1, rain_rate: 0)
    create_measurement(minutes_ago: 0, humidity: 50, temperature: 17, uvi: 0, rain_rate: 0)

    result = WeatherData::LiveCardHourlyRanges.new(now: @now).call
    humidity = result[:humidity]

    refute_includes humidity[:values].compact, 90
    assert_equal 50, humidity[:y_min]
    assert_equal 55, humidity[:y_max]
  end

  test "returns day-length series even when sparse so live updates can fill in" do
    create_measurement(minutes_ago: 0, humidity: 50, temperature: 17, uvi: 0, rain_rate: 0)

    result = WeatherData::LiveCardHourlyRanges.new(now: @now).call
    humidity = result[:humidity]

    assert_equal 144, humidity[:labels].length
    assert_equal 1, humidity[:values].compact.length
    assert_equal 50, humidity[:y_min]
    assert_equal 50, humidity[:y_max]
  end

  test "pressure sparkline uses sea-level from station pressure not relative" do
    previous = ENV["LOCATION_ELEVATION_FT"]
    ENV["LOCATION_ELEVATION_FT"] = "416"

    create_measurement_at(
      @now,
      humidity: 50, temperature: 17, uvi: 0, rain_rate: 0,
      barometer_abs: 29.63 * SeaLevelPressure::HPA_PER_INHG,
      barometer_rel: 29.54 * SeaLevelPressure::HPA_PER_INHG
    )

    pressure = WeatherData::LiveCardHourlyRanges.new(now: @now).call[:pressure]

    expected = SeaLevelPressure.qff_hpa(
      29.63 * SeaLevelPressure::HPA_PER_INHG,
      temp_c: 17,
      elevation_ft: 416
    ).round

    refute_includes pressure[:values].compact, 1000
    assert_equal expected, pressure[:y_max]
    assert_equal expected, pressure[:y_min]
  ensure
    previous.nil? ? ENV.delete("LOCATION_ELEVATION_FT") : ENV["LOCATION_ELEVATION_FT"] = previous
  end

  test "aqi sparkline ignores openweather rows" do
    Aqi.create!(
      observed_at: @now - 10.minutes,
      pm2_5: 425.8,
      epa_aqi: 451,
      source: "openweather"
    )
    Aqi.create!(
      observed_at: @now,
      pm2_5: 3.8,
      epa_aqi: 18,
      source: "airnow"
    )

    aqi = WeatherData::LiveCardHourlyRanges.new(now: @now).call[:aqi]

    assert_includes aqi[:values], 18
    refute_includes aqi[:values].compact, 451
    assert_equal 18, aqi[:y_min]
    assert_equal 18, aqi[:y_max]
  end

  private

  def create_measurement(minutes_ago:, humidity:, temperature:, uvi:, rain_rate:, wind_speed: 1, gust_speed: 2)
    create_measurement_at(
      @now - minutes_ago.minutes,
      humidity: humidity,
      temperature: temperature,
      uvi: uvi,
      rain_rate: rain_rate,
      wind_speed: wind_speed,
      gust_speed: gust_speed
    )
  end

  def create_measurement_at(reading_date_time, humidity:, temperature:, uvi:, rain_rate:, wind_speed: 1, gust_speed: 2, barometer_abs: 1013, barometer_rel: 1013)
    WeatherMeasurement.create!(
      reading_date_time: reading_date_time,
      barometer_abs: barometer_abs,
      barometer_rel: barometer_rel,
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
