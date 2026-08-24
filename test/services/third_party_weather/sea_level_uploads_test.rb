# frozen_string_literal: true

require "test_helper"
require "digest"

# Each network wants sea-level / altimeter, not the console relative offset
# and not raw station pressure. 29.63 inHg abs at 416 ft → ~1018.6 hPa / 30.079 inHg.
module ThirdPartyWeather
  class SeaLevelUploadsTest < ActiveSupport::TestCase
    FakeResponse = Struct.new(:code, :body, keyword_init: true)

    STATION_ABS_INHG = 29.63
    STATION_REL_INHG = 29.54
    ELEVATION_FT = 416
    EXPECTED_SLP_HPA = 1018.593
    EXPECTED_SLP_INHG = 30.079
    EXPECTED_TENTHS_HPA = 10_186

    setup do
      @original_get = HTTParty.method(:get)
      @measurement = WeatherMeasurement.create!(
        reading_date_time: Time.utc(2026, 8, 24, 12, 0, 0),
        barometer_abs: STATION_ABS_INHG * SeaLevelPressure::HPA_PER_INHG,
        barometer_rel: STATION_REL_INHG * SeaLevelPressure::HPA_PER_INHG,
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
    end

    teardown do
      HTTParty.define_singleton_method(:get, @original_get)
    end

    test "Weather Underground baromin is altimeter inHg not relative or station" do
      params = capture_query do
        with_upload_env("WU_STATION_ID" => "KWAAUBU154", "WU_STATION_KEY" => "wu-key") do
          WeatherUnderground.call(@measurement)
        end
      end

      assert_in_delta EXPECTED_SLP_INHG, params[:baromin], 0.002
      refute_in_delta STATION_REL_INHG, params[:baromin], 0.05
      refute_in_delta STATION_ABS_INHG, params[:baromin], 0.05
    end

    test "PWSWeather baromin matches Weather Underground altimeter" do
      params = capture_query do
        with_upload_env("PWS_STATION_ID" => "S50LEAHILL", "PWS_STATION_KEY" => "pws-key") do
          PwsWeather.call(@measurement)
        end
      end

      assert_in_delta EXPECTED_SLP_INHG, params[:baromin], 0.002
    end

    test "WeatherCloud bar is sea-level tenths of hPa" do
      params = capture_query do
        with_upload_env(
          "WEATHERCLOUD_DEVICE_ID" => "wc-id",
          "WEATHERCLOUD_DEVICE_KEY" => "wc-key"
        ) do
          Weathercloud.call(@measurement, lock_key: unique_lock("weathercloud"))
        end
      end

      assert_equal EXPECTED_TENTHS_HPA, params[:bar]
      refute_equal (STATION_REL_INHG * SeaLevelPressure::HPA_PER_INHG * 10).round, params[:bar]
      refute_equal (STATION_ABS_INHG * SeaLevelPressure::HPA_PER_INHG * 10).round, params[:bar]
    end

    test "AWEKAS field 7 is QFF and closes the -18.5 hPa QC gap" do
      params = capture_query do
        with_upload_env(
          "AWEKAS_USERNAME" => "awekas-user",
          "AWEKAS_PASSWORD" => "awekas-pass",
          "LOCATION_LAT" => "47.3073",
          "LOCATION_LON" => "-122.2285"
        ) do
          Awekas.call(@measurement, lock_key: unique_lock("awekas"))
        end
      end

      pressure = params[:val].split(";")[6].to_f
      relative_hpa = STATION_REL_INHG * SeaLevelPressure::HPA_PER_INHG
      expected_qff = SeaLevelPressure.qff_hpa(
        STATION_ABS_INHG * SeaLevelPressure::HPA_PER_INHG,
        temp_c: 20.0,
        elevation_ft: ELEVATION_FT
      ).round(1)

      assert_in_delta expected_qff, pressure, 0.05
      assert_in_delta(-18.5, relative_hpa - pressure, 1.0)
      refute_in_delta relative_hpa, pressure, 1.0
      refute_in_delta STATION_ABS_INHG * SeaLevelPressure::HPA_PER_INHG, pressure, 1.0
    end

    test "CWOP APRS b-field is sea-level tenths of millibars" do
      packet = with_upload_env(
        "LOCATION_LAT" => "47.3073",
        "LOCATION_LON" => "-122.2285"
      ) do
        Cwop::PacketBuilder.build(@measurement, callsign: "GW1125")
      end

      assert_includes packet, "b#{EXPECTED_TENTHS_HPA}"
      refute_includes packet, "b#{(STATION_REL_INHG * SeaLevelPressure::HPA_PER_INHG * 10).round}"
      refute_includes packet, "b#{(STATION_ABS_INHG * SeaLevelPressure::HPA_PER_INHG * 10).round}"
    end

    private

    def capture_query
      captured = nil
      HTTParty.define_singleton_method(:get) do |_url, **kwargs|
        captured = kwargs[:query]
        FakeResponse.new(code: 200, body: "success OK")
      end
      yield
      captured
    end

    def with_upload_env(vars, &block)
      with_env(vars.merge("LOCATION_ELEVATION_FT" => ELEVATION_FT.to_s), &block)
    end

    def unique_lock(service)
      "third_party_upload:#{service}:test:#{SecureRandom.hex(8)}"
    end
  end
end
