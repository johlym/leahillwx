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

    high = SeaLevelPressure.qff_hpa(29.63 * SeaLevelPressure::HPA_PER_INHG, temp_c: 20.0, elevation_ft: 416)
    low = SeaLevelPressure.qff_hpa(29.50 * SeaLevelPressure::HPA_PER_INHG, temp_c: 20.0, elevation_ft: 416)
    assert_in_delta high, record.highest_pressure, 0.1
    assert_in_delta low, record.lowest_pressure, 0.2
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

  test "all_time recalc keeps measurement extremes after raw rows are purged" do
    historic_high_at = Time.zone.parse("2022-07-15 16:00:00")
    historic_low_at = Time.zone.parse("2022-01-02 06:00:00")
    Record.create!(
      scope: "all_time",
      highest_temp: 45.0,
      highest_temp_at: historic_high_at,
      lowest_temp: -12.0,
      lowest_temp_at: historic_low_at,
      strongest_gust: 28.0,
      strongest_gust_at: historic_high_at,
      highest_rain_rate: 15.0,
      highest_rain_rate_at: historic_high_at,
      highest_solar: 1200.0,
      highest_solar_at: historic_high_at
    )

    WeatherMeasurement.create!(measurement_attrs(
      reading_date_time: Time.zone.parse("2025-08-01 12:00:00"),
      temperature: 32.0,
      gust_speed: 8.0,
      rain_rate: 2.0,
      light: 800.0
    ))
    WeatherMeasurement.create!(measurement_attrs(
      reading_date_time: Time.zone.parse("2025-01-10 12:00:00"),
      temperature: 2.0,
      gust_speed: 3.0,
      rain_rate: 0.0,
      light: 200.0
    ))

    record = RecordCalculator.new(scope: "all_time").calculate_and_save!

    assert_equal 45.0, record.highest_temp
    assert_equal historic_high_at, record.highest_temp_at
    assert_equal(-12.0, record.lowest_temp)
    assert_equal historic_low_at, record.lowest_temp_at
    assert_equal 28.0, record.strongest_gust
    assert_equal 15.0, record.highest_rain_rate
    assert_equal 1200.0, record.highest_solar
  end

  test "all_time recalc still advances when remaining measurements set a new extreme" do
    Record.create!(
      scope: "all_time",
      highest_temp: 30.0,
      highest_temp_at: Time.zone.parse("2022-07-15 16:00:00"),
      lowest_temp: 0.0,
      lowest_temp_at: Time.zone.parse("2022-01-02 06:00:00")
    )

    new_high_at = Time.zone.parse("2025-08-01 15:00:00")
    new_low_at = Time.zone.parse("2025-01-10 07:00:00")
    WeatherMeasurement.create!(measurement_attrs(
      reading_date_time: new_high_at,
      temperature: 41.0
    ))
    WeatherMeasurement.create!(measurement_attrs(
      reading_date_time: new_low_at,
      temperature: -8.0
    ))

    record = RecordCalculator.new(scope: "all_time").calculate_and_save!

    assert_equal 41.0, record.highest_temp
    assert_equal new_high_at, record.highest_temp_at
    assert_equal(-8.0, record.lowest_temp)
    assert_equal new_low_at, record.lowest_temp_at
  end

  test "all_time recalc recovers a purged extreme from a yearly record" do
    historic_high_at = Time.zone.parse("2022-07-15 16:00:00")
    Record.create!(
      scope: "yearly",
      year: 2022,
      highest_temp: 44.0,
      highest_temp_at: historic_high_at
    )

    WeatherMeasurement.create!(measurement_attrs(
      reading_date_time: Time.zone.parse("2025-08-01 12:00:00"),
      temperature: 31.0
    ))

    record = RecordCalculator.new(scope: "all_time").calculate_and_save!

    assert_equal 44.0, record.highest_temp
    assert_equal historic_high_at, record.highest_temp_at
  end

  test "yearly recalc still overwrites from that year's remaining measurements" do
    Record.create!(
      scope: "yearly",
      year: 2024,
      highest_temp: 50.0,
      highest_temp_at: Time.zone.parse("2024-07-01 12:00:00"),
      lowest_temp: -20.0,
      lowest_temp_at: Time.zone.parse("2024-01-01 12:00:00")
    )

    WeatherMeasurement.create!(measurement_attrs(
      reading_date_time: Time.zone.parse("2024-07-10 12:00:00"),
      temperature: 33.0
    ))
    WeatherMeasurement.create!(measurement_attrs(
      reading_date_time: Time.zone.parse("2024-01-10 12:00:00"),
      temperature: 4.0
    ))

    record = RecordCalculator.new(scope: "yearly", year: 2024).calculate_and_save!

    assert_equal 33.0, record.highest_temp
    assert_equal 4.0, record.lowest_temp
  end
end
