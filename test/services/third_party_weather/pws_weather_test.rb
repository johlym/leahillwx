# frozen_string_literal: true

require "test_helper"

module ThirdPartyWeather
  class PwsWeatherTest < ActiveSupport::TestCase
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

      ENV["PWS_STATION_ID"] = "S50LEAHILL"
      ENV["PWS_STATION_KEY"] = "pws-key"
    end

    teardown do
      HTTParty.define_singleton_method(:get, @original_get)
      ENV.delete("PWS_STATION_ID")
      ENV.delete("PWS_STATION_KEY")
    end

    test "GETs PWSWeather endpoint with spaced dateutc" do
      captured_url = nil
      captured = nil
      HTTParty.define_singleton_method(:get) do |url, **kwargs|
        captured_url = url
        captured = kwargs
        FakeResponse.new(code: 200, body: "success")
      end

      PwsWeather.call(@measurement)

      assert_equal PwsWeather::URL, captured_url
      assert_equal "2026-07-18 12:00:00", captured[:query][:dateutc]
      refute_includes captured[:query][:dateutc], "+"
      assert_in_delta @measurement.sea_level_pressure_inhg.round(3), captured[:query][:baromin], 0.001
    end

    test "swallows transient connection resets without raising" do
      HTTParty.define_singleton_method(:get) do |*_args, **_kwargs|
        raise Errno::ECONNRESET, "Connection reset by peer"
      end

      assert_nothing_raised do
        PwsWeather.call(@measurement)
      end
    end
  end
end
