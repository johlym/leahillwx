# frozen_string_literal: true

require "test_helper"
require "sidekiq/testing"

class UpdateThirdPartyWeatherPlatformsJobTest < ActiveSupport::TestCase
  setup do
    Sidekiq::Testing.fake!
    Sidekiq::Worker.clear_all
    @original_send_wx = ENV["SEND_WX"]
  end

  teardown do
    if @original_send_wx
      ENV["SEND_WX"] = @original_send_wx
    else
      ENV.delete("SEND_WX")
    end
    Sidekiq::Worker.clear_all
  end

  def create_measurement!
    WeatherMeasurement.create!(
      reading_date_time: Time.current.change(usec: 0),
      barometer_abs: 1013.2,
      barometer_rel: 1015.0,
      gust_speed: 2.5,
      light: 1200.0,
      humidity: 65,
      temperature: 18.5,
      rain_day: 0.0,
      rain_rate: 0.0,
      uv: 3,
      uvi: 3.0,
      wind_dir: 180,
      wind_speed: 1.2
    )
  end

  test "does nothing when SEND_WX is not true" do
    ENV["SEND_WX"] = "false"
    create_measurement!

    UpdateThirdPartyWeatherPlatformsJob.new.perform

    assert_equal 0, UpdateWeatherUndergroundJob.jobs.size
    assert_equal 0, UpdatePwsWeatherJob.jobs.size
    assert_equal 0, UpdateAwekasJob.jobs.size
    assert_equal 0, UpdateWeathercloudJob.jobs.size
    assert_equal 0, UpdateCwopJob.jobs.size
  end

  test "does nothing when there are no measurements" do
    ENV["SEND_WX"] = "true"
    WeatherMeasurement.delete_all

    UpdateThirdPartyWeatherPlatformsJob.new.perform

    assert_equal 0, UpdateWeatherUndergroundJob.jobs.size
  end

  test "enqueues all service jobs for the latest measurement" do
    ENV["SEND_WX"] = "true"
    older = create_measurement!
    newer = WeatherMeasurement.create!(
      reading_date_time: older.reading_date_time + 1.minute,
      barometer_abs: 1013.2,
      barometer_rel: 1015.0,
      gust_speed: 2.5,
      light: 1200.0,
      humidity: 65,
      temperature: 19.0,
      rain_day: 0.0,
      rain_rate: 0.0,
      uv: 3,
      uvi: 3.0,
      wind_dir: 90,
      wind_speed: 1.5
    )

    UpdateThirdPartyWeatherPlatformsJob.new.perform

    [
      UpdateWeatherUndergroundJob,
      UpdatePwsWeatherJob,
      UpdateAwekasJob,
      UpdateWeathercloudJob,
      UpdateCwopJob
    ].each do |job_class|
      assert_equal 1, job_class.jobs.size
      assert_equal [ newer.id ], job_class.jobs.first["args"]
    end
  end
end
