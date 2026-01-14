require "test_helper"

class RemoveDuplicateWeatherMeasurementsJobTest < ActiveSupport::TestCase
  test "removes duplicate weather measurements with same reading_date_time" do
    date_time = Time.zone.parse("2024-01-01 12:00:00")

    # Create three records with the same reading_date_time
    first = WeatherMeasurement.create!(
      reading_date_time: date_time,
      barometer_abs: 30.0,
      barometer_rel: 30.0,
      gust_speed: 5.0,
      humidity: 50,
      light: 100.0,
      rain_day: 0.0,
      rain_rate: 0.0,
      temperature: 20.0,
      uv: 5,
      uvi: 5.0,
      wind_dir: 180,
      wind_speed: 3.0
    )

    second = WeatherMeasurement.create!(
      reading_date_time: date_time,
      barometer_abs: 30.0,
      barometer_rel: 30.0,
      gust_speed: 5.0,
      humidity: 50,
      light: 100.0,
      rain_day: 0.0,
      rain_rate: 0.0,
      temperature: 20.0,
      uv: 5,
      uvi: 5.0,
      wind_dir: 180,
      wind_speed: 3.0
    )

    third = WeatherMeasurement.create!(
      reading_date_time: date_time,
      barometer_abs: 30.0,
      barometer_rel: 30.0,
      gust_speed: 5.0,
      humidity: 50,
      light: 100.0,
      rain_day: 0.0,
      rain_rate: 0.0,
      temperature: 20.0,
      uv: 5,
      uvi: 5.0,
      wind_dir: 180,
      wind_speed: 3.0
    )

    assert_equal 3, WeatherMeasurement.where(reading_date_time: date_time).count

    RemoveDuplicateWeatherMeasurementsJob.new.perform

    assert_equal 1, WeatherMeasurement.where(reading_date_time: date_time).count
    assert WeatherMeasurement.exists?(first.id), "First record should be kept"
    assert_not WeatherMeasurement.exists?(second.id), "Second record should be deleted"
    assert_not WeatherMeasurement.exists?(third.id), "Third record should be deleted"
  end

  test "does not affect records with unique reading_date_times" do
    unique_measurement = WeatherMeasurement.create!(
      reading_date_time: Time.zone.parse("2024-01-02 12:00:00"),
      barometer_abs: 30.0,
      barometer_rel: 30.0,
      gust_speed: 5.0,
      humidity: 50,
      light: 100.0,
      rain_day: 0.0,
      rain_rate: 0.0,
      temperature: 20.0,
      uv: 5,
      uvi: 5.0,
      wind_dir: 180,
      wind_speed: 3.0
    )

    RemoveDuplicateWeatherMeasurementsJob.new.perform

    assert WeatherMeasurement.exists?(unique_measurement.id), "Unique record should not be deleted"
  end
end
