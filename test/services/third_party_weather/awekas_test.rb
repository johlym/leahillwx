# frozen_string_literal: true

require "test_helper"
require "digest"

module ThirdPartyWeather
  class AwekasTest < ActiveSupport::TestCase
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

      ENV["AWEKAS_USERNAME"] = "awekas-user"
      ENV["AWEKAS_PASSWORD"] = "awekas-pass"
      ENV["LOCATION_LAT"] = "47.3073"
      ENV["LOCATION_LON"] = "-122.2285"
      @lock_key = "third_party_upload:awekas:test:#{SecureRandom.hex(8)}"
    end

    teardown do
      HTTParty.define_singleton_method(:get, @original_get)
      %w[AWEKAS_USERNAME AWEKAS_PASSWORD LOCATION_LAT LOCATION_LON].each { |key| ENV.delete(key) }
      Sidekiq.redis { |conn| conn.del(@lock_key) }
    end

    test "sends username and MD5 password hash to eingabe_pruefung" do
      captured_url = nil
      captured = nil
      HTTParty.define_singleton_method(:get) do |url, **kwargs|
        captured_url = url
        captured = kwargs
        FakeResponse.new(code: 200, body: "OK")
      end

      Awekas.call(@measurement, lock_key: @lock_key)

      assert_equal Awekas::URL, captured_url
      values = captured[:query][:val].split(";")
      assert_equal "awekas-user", values[0]
      assert_equal Digest::MD5.hexdigest("awekas-pass"), values[1]
      assert_equal "18.07.2026", values[2]
      assert_equal "12:00", values[3]
      assert_equal "20.0", values[4]
      assert_in_delta @measurement.sea_level_pressure, values[6].to_f, 0.001
      assert_equal "-122.2285", values[-2]
      assert_equal "47.3073", values[-1]
    end

    test "throttles repeated sends within five minutes" do
      get_count = 0
      HTTParty.define_singleton_method(:get) do |_url, **_kwargs|
        get_count += 1
        FakeResponse.new(code: 200, body: "OK")
      end

      service = Awekas.new(@measurement, lock_key: @lock_key)
      service.call
      service.call

      assert_equal 1, get_count
    end
  end
end
