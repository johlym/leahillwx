# frozen_string_literal: true

require "test_helper"

class UpdateWeatherUndergroundJobTest < ActiveSupport::TestCase
  FakeResponse = Struct.new(:code, :body, keyword_init: true) do
    def success?
      code.to_i.between?(200, 299)
    end
  end

  setup do
    @original_post = HTTParty.method(:post)
    @original_id = ENV["WU_STATION_ID"]
    @original_key = ENV["WU_STATION_KEY"]
    @measurement = WeatherMeasurement.create!(
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

  teardown do
    HTTParty.define_singleton_method(:post, @original_post)
    restore_env("WU_STATION_ID", @original_id)
    restore_env("WU_STATION_KEY", @original_key)
  end

  test "skips when credentials are missing" do
    ENV.delete("WU_STATION_ID")
    ENV.delete("WU_STATION_KEY")
    called = false
    HTTParty.define_singleton_method(:post) do |*_args, **_kwargs|
      called = true
      FakeResponse.new(code: 200, body: "success")
    end

    UpdateWeatherUndergroundJob.new.perform(@measurement.id)

    assert_not called
  end

  test "calls service when credentials are present" do
    ENV["WU_STATION_ID"] = "KWAAUBU154"
    ENV["WU_STATION_KEY"] = "secret"
    called = false
    HTTParty.define_singleton_method(:post) do |*_args, **_kwargs|
      called = true
      FakeResponse.new(code: 200, body: "success")
    end

    UpdateWeatherUndergroundJob.new.perform(@measurement.id)

    assert called
  end

  private

  def restore_env(key, value)
    if value
      ENV[key] = value
    else
      ENV.delete(key)
    end
  end
end
