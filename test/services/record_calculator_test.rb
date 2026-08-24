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

  test "calculate_and_save! uses sea-level pressure from station abs not relative" do
    previous = ENV["LOCATION_ELEVATION_FT"]
    ENV["LOCATION_ELEVATION_FT"] = "416"

    WeatherMeasurement.create!(measurement_attrs(
      reading_date_time: Time.zone.parse("2024-06-15 10:00:00"),
      barometer_abs: 29.63 * SeaLevelPressure::HPA_PER_INHG,
      barometer_rel: 29.54 * SeaLevelPressure::HPA_PER_INHG
    ))
    WeatherMeasurement.create!(measurement_attrs(
      reading_date_time: Time.zone.parse("2024-06-15 16:00:00"),
      barometer_abs: 29.50 * SeaLevelPressure::HPA_PER_INHG,
      barometer_rel: 29.40 * SeaLevelPressure::HPA_PER_INHG
    ))

    record = RecordCalculator.new(scope: "yearly", year: 2024).calculate_and_save!

    assert_in_delta 1018.6, record.highest_pressure, 0.1
    assert_in_delta 1014.1, record.lowest_pressure, 0.2
    assert record.largest_pressure_swing.positive?
    refute_in_delta 1000.3, record.highest_pressure, 1.0
  ensure
    previous.nil? ? ENV.delete("LOCATION_ELEVATION_FT") : ENV["LOCATION_ELEVATION_FT"] = previous
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
