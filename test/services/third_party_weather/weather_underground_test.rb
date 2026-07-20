# frozen_string_literal: true

require "test_helper"

module ThirdPartyWeather
  class WeatherUndergroundTest < ActiveSupport::TestCase
    FakeResponse = Struct.new(:code, :body, keyword_init: true)

    setup do
      @original_get = HTTParty.method(:get)
      @measurement = WeatherMeasurement.create!(
        reading_date_time: Time.utc(2026, 7, 18, 12, 0, 0),
        barometer_abs: 1013.2,
        barometer_rel: 1015.0,
        gust_speed: 4.0,
        light: 500.0,
        humidity: 65,
        temperature: 20.0,
        rain_day: 2.54,
        rain_rate: 1.27,
        uv: 3,
        uvi: 3.0,
        wind_dir: 180,
        wind_speed: 2.0
      )

      ENV["WU_STATION_ID"] = "KWAAUBU154"
      ENV["WU_STATION_KEY"] = "wu-key"
    end

    teardown do
      HTTParty.define_singleton_method(:get, @original_get)
      ENV.delete("WU_STATION_ID")
      ENV.delete("WU_STATION_KEY")
    end

    test "skips upload when required credentials are missing" do
      ENV.delete("WU_STATION_ID")
      ENV.delete("WU_STATION_KEY")
      called = false
      HTTParty.define_singleton_method(:get) do |*_args, **_kwargs|
        called = true
        FakeResponse.new(code: 200, body: "success")
      end

      WeatherUnderground.call(@measurement.id)

      assert_not called
    end

    test "call accepts a measurement id" do
      called = false
      HTTParty.define_singleton_method(:get) do |*_args, **_kwargs|
        called = true
        FakeResponse.new(code: 200, body: "success")
      end

      WeatherUnderground.call(@measurement.id)

      assert called
    end

    test "GETs expected imperial fields and spaced dateutc" do
      captured_url = nil
      captured = nil
      HTTParty.define_singleton_method(:get) do |url, **kwargs|
        captured_url = url
        captured = kwargs
        FakeResponse.new(code: 200, body: "success")
      end

      WeatherUnderground.call(@measurement)

      assert_equal WeatherUnderground::URL, captured_url
      params = captured[:query]
      assert_equal "KWAAUBU154", params[:ID]
      assert_equal "wu-key", params[:PASSWORD]
      assert_equal "2026-07-18 12:00:00", params[:dateutc]
      refute_includes params[:dateutc], "+"
      assert_equal 180, params[:winddir]
      assert_in_delta @measurement.wind_speed_mph.round(2), params[:windspeedmph], 0.001
      assert_in_delta @measurement.gust_speed_mph.round(2), params[:windgustmph], 0.001
      assert_in_delta @measurement.temperature.to_fahrenheit.round(2), params[:tempf], 0.001
      assert_in_delta @measurement.rain_rate_in.round(4), params[:rainin], 0.0001
      assert_in_delta @measurement.rain_day_in.round(4), params[:dailyrainin], 0.0001
      assert_in_delta @measurement.barometer_rel_inhg.round(3), params[:baromin], 0.001
      assert_in_delta @measurement.dew_point.to_fahrenheit.round(2), params[:dewptf], 0.001
      assert_equal 65, params[:humidity]
      assert_equal 10, captured[:timeout]
    end
  end
end
