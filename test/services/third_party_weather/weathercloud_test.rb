# frozen_string_literal: true

require "test_helper"

module ThirdPartyWeather
  class WeathercloudTest < ActiveSupport::TestCase
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

      ENV["WEATHERCLOUD_DEVICE_ID"] = "wc-id"
      ENV["WEATHERCLOUD_DEVICE_KEY"] = "wc-key"
      @lock_key = "third_party_upload:weathercloud:test:#{SecureRandom.hex(8)}"
    end

    teardown do
      HTTParty.define_singleton_method(:get, @original_get)
      ENV.delete("WEATHERCLOUD_DEVICE_ID")
      ENV.delete("WEATHERCLOUD_DEVICE_KEY")
      Sidekiq.redis { |conn| conn.del(@lock_key) }
    end

    test "uses https and scaled metric values" do
      captured_url = nil
      captured = nil
      HTTParty.define_singleton_method(:get) do |url, **kwargs|
        captured_url = url
        captured = kwargs
        FakeResponse.new(code: 200, body: "OK")
      end

      Weathercloud.call(@measurement, lock_key: @lock_key)

      assert_equal Weathercloud::URL, captured_url
      params = captured[:query]
      assert_equal "wc-id", params[:wid]
      assert_equal 200, params[:temp]
      assert_equal 65, params[:hum]
      assert_equal 20, params[:wspd]
      assert_equal 40, params[:wspdhi]
      assert_equal 10132, params[:bar]
    end

    test "throttles repeated sends within ten minutes" do
      get_count = 0
      HTTParty.define_singleton_method(:get) do |_url, **_kwargs|
        get_count += 1
        FakeResponse.new(code: 200, body: "OK")
      end

      service = Weathercloud.new(@measurement, lock_key: @lock_key)
      service.call
      service.call

      assert_equal 1, get_count
    end
  end
end
