# frozen_string_literal: true

require "test_helper"

class Records::TemperatureExtremesTest < ActiveSupport::TestCase
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

  test "heat index and wind chill come from feels_like among qualifying rows" do
    heat_at = Time.zone.parse("2024-07-20 16:00:00")
    chill_at = Time.zone.parse("2024-01-12 06:00:00")
    WeatherMeasurement.create!(measurement_attrs(
      reading_date_time: heat_at,
      temperature: 32.0,
      humidity: 70,
      wind_speed: 1.0
    ))
    WeatherMeasurement.create!(measurement_attrs(
      reading_date_time: Time.zone.parse("2024-07-21 16:00:00"),
      temperature: 28.0,
      humidity: 45,
      wind_speed: 1.0
    ))
    WeatherMeasurement.create!(measurement_attrs(
      reading_date_time: chill_at,
      temperature: -4.0,
      humidity: 80,
      wind_speed: 8.0
    ))
    WeatherMeasurement.create!(measurement_attrs(
      reading_date_time: Time.zone.parse("2024-01-13 06:00:00"),
      temperature: 2.0,
      humidity: 80,
      wind_speed: 2.0
    ))

    record = RecordCalculator.new(scope: "yearly", year: 2024).calculate_and_save!

    assert_equal heat_at, record.highest_heat_index_at
    assert_in_delta WeatherMeasurement.find_by!(reading_date_time: heat_at).feels_like, record.highest_heat_index, 0.01
    assert_equal chill_at, record.lowest_wind_chill_at
    assert_in_delta WeatherMeasurement.find_by!(reading_date_time: chill_at).feels_like, record.lowest_wind_chill, 0.01
  end

  test "heat index and wind chill queries rank by formula and stay LIMIT 1" do
    WeatherMeasurement.create!(measurement_attrs(
      reading_date_time: Time.zone.parse("2024-07-20 16:00:00"),
      temperature: 32.0,
      humidity: 70,
      wind_speed: 1.0
    ))
    WeatherMeasurement.create!(measurement_attrs(
      reading_date_time: Time.zone.parse("2024-01-12 06:00:00"),
      temperature: -4.0,
      humidity: 80,
      wind_speed: 8.0
    ))

    sql = []
    callback = lambda { |*_, payload| sql << payload[:sql].to_s }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      RecordCalculator.new(scope: "yearly", year: 2024).calculate_and_save!
    end

    heat_sql = sql.select { |query| query.include?("temperature > 27") && query.include?("humidity >= 40") }
    chill_sql = sql.select { |query| query.include?("temperature < 10") && query.include?("wind_speed > 1.34") }

    assert heat_sql.any? { |query| query.include?("2.04901523") && query.match?(/LIMIT(?:\s+1|\s+\$\d+)/i) },
           "expected heat-index ORDER BY formula LIMIT 1, got:\n#{heat_sql.join("\n")}"
    assert chill_sql.any? { |query| query.include?("11.37") && query.match?(/LIMIT(?:\s+1|\s+\$\d+)/i) },
           "expected wind-chill ORDER BY formula LIMIT 1, got:\n#{chill_sql.join("\n")}"
  end

  test "heat index record is the humid peak not the 250 hottest dry minutes" do
    now = Time.current
    start = Time.zone.parse("2024-07-20 00:00:00")
    peak_at = Time.zone.parse("2024-07-21 16:00:00")
    rows = 250.times.map do |i|
      insert_attrs(reading_date_time: start + i.minutes, temperature: 38.0, humidity: 40, wind_speed: 1.0, now: now)
    end
    rows << insert_attrs(reading_date_time: peak_at, temperature: 31.0, humidity: 90, wind_speed: 1.0, now: now)
    WeatherMeasurement.insert_all!(rows)

    record = RecordCalculator.new(scope: "yearly", year: 2024).calculate_and_save!

    assert_equal peak_at, record.highest_heat_index_at
    assert_in_delta WeatherMeasurement.find_by!(reading_date_time: peak_at).heat_index_c(31.0, 90),
                    record.highest_heat_index, 0.01
  end

  test "wind chill record is the windy storm not the 250 coldest light-wind minutes" do
    now = Time.current
    start = Time.zone.parse("2024-01-10 00:00:00")
    storm_at = Time.zone.parse("2024-01-12 18:00:00")
    rows = 250.times.map do |i|
      insert_attrs(reading_date_time: start + i.minutes, temperature: -6.0, humidity: 80, wind_speed: 1.4, now: now)
    end
    rows << insert_attrs(reading_date_time: storm_at, temperature: -1.0, humidity: 80, wind_speed: 25.0, now: now)
    WeatherMeasurement.insert_all!(rows)

    record = RecordCalculator.new(scope: "yearly", year: 2024).calculate_and_save!

    assert_equal storm_at, record.lowest_wind_chill_at
    assert_in_delta WeatherMeasurement.find_by!(reading_date_time: storm_at).wind_chill_c(-1.0, 25.0),
                    record.lowest_wind_chill, 0.01
  end

  def insert_attrs(reading_date_time:, temperature:, humidity:, wind_speed:, now:)
    {
      reading_date_time: reading_date_time,
      barometer_abs: 1013.0,
      barometer_rel: 1015.0,
      gust_speed: 2.0,
      light: 1000.0,
      humidity: humidity,
      temperature: temperature,
      rain_day: 0.0,
      rain_rate: 0.0,
      uv: 3,
      uvi: 3.0,
      wind_dir: 180,
      wind_speed: wind_speed,
      soil: [],
      temp_humidity: [],
      temp_probes: [],
      created_at: now,
      updated_at: now
    }
  end
end
