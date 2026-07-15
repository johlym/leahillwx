require "test_helper"

class RecordCalculatorTest < ActiveSupport::TestCase
  def measurement_attrs(overrides = {})
    {
      reading_date_time: Time.zone.parse("2024-06-15 12:00:00"),
      barometer_abs: 1013.0,
      barometer_rel: 1015.0,
      gust_speed: 2.0,
      light: 1000.0,
      humidity: 50,
      temperature: 20.0,
      rain_day: 0.0,
      rain_rate: 0.0,
      uv: 3,
      uvi: 3.0,
      wind_dir: 180,
      wind_speed: 1.0,
      soil: []
    }.merge(overrides)
  end

  test "calculate_and_save! persists yearly temperature extremes" do
    WeatherMeasurement.create!(measurement_attrs(
      reading_date_time: Time.zone.parse("2024-01-10 12:00:00"),
      temperature: 5.0
    ))
    WeatherMeasurement.create!(measurement_attrs(
      reading_date_time: Time.zone.parse("2024-07-10 12:00:00"),
      temperature: 35.0,
      humidity: 40,
      wind_speed: 1.0
    ))
    WeatherMeasurement.create!(measurement_attrs(
      reading_date_time: Time.zone.parse("2023-07-10 12:00:00"),
      temperature: 50.0
    ))

    record = RecordCalculator.new(scope: "yearly", year: 2024).calculate_and_save!

    assert record.persisted?
    assert_equal "yearly", record.scope
    assert_equal 2024, record.year
    assert_equal 35.0, record.highest_temp
    assert_equal 5.0, record.lowest_temp
  end

  test "calculate_and_save! creates an all_time record" do
    WeatherMeasurement.create!(measurement_attrs(
      reading_date_time: Time.zone.parse("2022-01-01 12:00:00"),
      temperature: -5.0
    ))
    WeatherMeasurement.create!(measurement_attrs(
      reading_date_time: Time.zone.parse("2024-08-01 12:00:00"),
      temperature: 40.0
    ))

    record = RecordCalculator.new(scope: "all_time").calculate_and_save!

    assert record.persisted?
    assert_equal "all_time", record.scope
    assert_nil record.year
    assert_equal 40.0, record.highest_temp
    assert_equal(-5.0, record.lowest_temp)
  end
end
