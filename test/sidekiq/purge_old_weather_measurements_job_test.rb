# frozen_string_literal: true

require "test_helper"

class PurgeOldWeatherMeasurementsJobTest < ActiveSupport::TestCase
  test "deletes measurements older than the retention window and keeps newer rows" do
    stale = create_measurement!(reading_date_time: 4.years.ago)
    recent = create_measurement!(reading_date_time: 1.day.ago)

    deleted = PurgeOldWeatherMeasurementsJob.new.perform

    assert_operator deleted, :>=, 1
    assert_not WeatherMeasurement.exists?(stale.id)
    assert WeatherMeasurement.exists?(recent.id)
    assert_equal WeatherMeasurement.count, WeatherMeasurements::TotalCount.read
  end

  test "does not delete rows newer than a stubbed cutoff" do
    recent = create_measurement!(reading_date_time: 30.days.ago)

    with_env("MEASUREMENT_RETENTION_DAYS" => "1095") do
      PurgeOldWeatherMeasurementsJob.new.perform
    end

    assert WeatherMeasurement.exists?(recent.id)
  end

  private

  def create_measurement!(**attrs)
    WeatherMeasurement.create!(
      {
        reading_date_time: Time.current,
        barometer_abs: 1013.25,
        barometer_rel: 1013.25,
        gust_speed: 1.0,
        light: 100,
        humidity: 50,
        temperature: 20,
        rain_day: 0,
        rain_rate: 0,
        uv: 0,
        uvi: 0,
        wind_dir: 180,
        wind_speed: 1.0
      }.merge(attrs)
    )
  end
end
