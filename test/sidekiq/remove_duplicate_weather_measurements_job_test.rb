require "test_helper"

class RemoveDuplicateWeatherMeasurementsJobTest < ActiveSupport::TestCase
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

    assert_nothing_raised do
      RemoveDuplicateWeatherMeasurementsJob.new.perform
    end

    assert WeatherMeasurement.exists?(unique_measurement.id), "Unique record should not be deleted"
  end
end
