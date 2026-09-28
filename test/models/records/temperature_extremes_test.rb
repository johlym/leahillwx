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

  test "heat index and wind chill queries stay LIMIT 250" do
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

    assert heat_sql.any? { |query| query.match?(/LIMIT(?:\s+\d+|\s+\$\d+)/i) },
           "expected bounded heat-index scan, got:\n#{heat_sql.join("\n")}"
    assert chill_sql.any? { |query| query.match?(/LIMIT(?:\s+\d+|\s+\$\d+)/i) },
           "expected bounded wind-chill scan, got:\n#{chill_sql.join("\n")}"
  end
end
