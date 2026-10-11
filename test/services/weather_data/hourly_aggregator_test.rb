# frozen_string_literal: true

require "test_helper"

class WeatherData::HourlyAggregatorTest < ActiveSupport::TestCase
  setup do
    @zone = ActiveSupport::TimeZone["America/Los_Angeles"]
  end

  test "hour rain is the counter increase, not max minus min" do
    create_reading(@zone.local(2024, 6, 15, 10, 0, 0), rain_day: 2.54)
    create_reading(@zone.local(2024, 6, 15, 10, 20, 0), rain_day: 0.0)
    create_reading(@zone.local(2024, 6, 15, 10, 40, 0), rain_day: 1.27)

    entry = WeatherData::HourlyAggregator.new(@zone.local(2024, 6, 15, 10, 30, 0)).aggregate

    # max - min would be 2.54. The counter ended 1.27 above the hour's start of 0
    # only after a same-hour correction, so the net new rain is 1.27.
    assert_in_delta 1.27, entry.rain, 0.001
    assert_equal 10, entry.hour
    assert_equal 15, entry.day
  end

  test "carryover that resets during the midnight hour is not rain" do
    create_reading(@zone.local(2024, 6, 14, 23, 50, 0), rain_day: 5.842)
    create_reading(@zone.local(2024, 6, 15, 0, 2, 0), rain_day: 5.842)
    create_reading(@zone.local(2024, 6, 15, 0, 10, 0), rain_day: 0.0)
    create_reading(@zone.local(2024, 6, 15, 0, 40, 0), rain_day: 0.0)

    entry = WeatherData::HourlyAggregator.new(@zone.local(2024, 6, 15, 0, 30, 0)).aggregate

    assert_in_delta 0.0, entry.rain, 0.001
  end

  test "buckets the hour in Pacific time when given a UTC clock time" do
    # 07:30 UTC on June 15 is 00:30 PDT.
    create_reading(Time.utc(2024, 6, 15, 7, 10, 0), rain_day: 1.0)
    create_reading(Time.utc(2024, 6, 15, 7, 40, 0), rain_day: 2.0)

    entry = WeatherData::HourlyAggregator.new(Time.utc(2024, 6, 15, 7, 30, 0)).aggregate

    assert_equal 15, entry.day
    assert_equal 0, entry.hour
    assert_in_delta 2.0, entry.rain, 0.001
    assert_equal "00:10", entry.high_temp_time
  end

  private

  def create_reading(time, rain_day:)
    WeatherMeasurement.create!(
      reading_date_time: time,
      barometer_abs: 1013.0,
      barometer_rel: 1013.0,
      gust_speed: 1.0,
      humidity: 50,
      light: 0.0,
      rain_day: rain_day,
      rain_rate: 0.0,
      temperature: 15.0,
      uv: 0,
      uvi: 0.0,
      wind_dir: 180,
      wind_speed: 1.0
    )
  end
end
