# frozen_string_literal: true

require "test_helper"
require "digest"

class UpdateThirdPartyWeatherPlatformServiceTest < ActiveSupport::TestCase
  FakeResponse = Struct.new(:code, :body, keyword_init: true) do
    def success?
      code.to_i.between?(200, 299)
    end
  end

  FakeSocket = Struct.new(:writes, :reads, keyword_init: true) do
    def initialize(writes: [], reads: [ "banner\n", "logresp\n" ])
      super(writes: writes, reads: reads)
      @read_index = 0
      @closed = false
    end

    def gets
      line = reads[@read_index]
      @read_index += 1
      line
    end

    def write(data)
      writes << data
    end

    def setsockopt(*)
      true
    end

    def close
      @closed = true
    end

    def closed?
      @closed
    end
  end

  class FakeSocketFactory
    attr_reader :opens, :socket

    def initialize(socket)
      @socket = socket
      @opens = []
    end

    def open(host, port)
      opens << [ host, port ]
      socket
    end
  end

  setup do
    @original_get = HTTParty.method(:get)
    @original_post = HTTParty.method(:post)
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
    ENV["PWS_STATION_ID"] = "S50LEAHILL"
    ENV["PWS_STATION_KEY"] = "pws-key"
    ENV["AWEKAS_USERNAME"] = "awekas-user"
    ENV["AWEKAS_PASSWORD"] = "awekas-pass"
    ENV["WEATHERCLOUD_DEVICE_ID"] = "wc-id"
    ENV["WEATHERCLOUD_DEVICE_KEY"] = "wc-key"
    ENV["CWOP_CALLSIGN"] = "GW1125"
    ENV["LOCATION_LAT"] = "47.3073"
    ENV["LOCATION_LON"] = "-122.2285"

    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    HTTParty.define_singleton_method(:get, @original_get)
    HTTParty.define_singleton_method(:post, @original_post)

    %w[
      WU_STATION_ID WU_STATION_KEY
      PWS_STATION_ID PWS_STATION_KEY
      AWEKAS_USERNAME AWEKAS_PASSWORD
      WEATHERCLOUD_DEVICE_ID WEATHERCLOUD_DEVICE_KEY
      CWOP_CALLSIGN LOCATION_LAT LOCATION_LON
    ].each { |key| ENV.delete(key) }

    Rails.cache = @original_cache
  end

  test "rejects unsupported services" do
    assert_raises(ArgumentError) do
      UpdateThirdPartyWeatherPlatformService.new(@measurement, "windy")
    end
  end

  test "update_weatherunderground posts expected imperial fields" do
    captured = nil
    HTTParty.define_singleton_method(:post) do |_url, **kwargs|
      captured = kwargs
      FakeResponse.new(code: 200, body: "success")
    end

    UpdateThirdPartyWeatherPlatformService.new(@measurement, "weatherunderground").perform

    params = captured[:query]
    assert_equal "KWAAUBU154", params[:ID]
    assert_equal "wu-key", params[:PASSWORD]
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

  test "update_pwsweather posts to PWSWeather endpoint" do
    captured_url = nil
    HTTParty.define_singleton_method(:post) do |url, **_kwargs|
      captured_url = url
      FakeResponse.new(code: 200, body: "success")
    end

    UpdateThirdPartyWeatherPlatformService.new(@measurement, "pwsweather").perform

    assert_equal "https://www.pwsweather.com/pwsupdate/pwsupdate.php", captured_url
  end

  test "update_awekas sends username and MD5 password hash" do
    captured = nil
    HTTParty.define_singleton_method(:get) do |_url, **kwargs|
      captured = kwargs
      FakeResponse.new(code: 200, body: "OK")
    end

    UpdateThirdPartyWeatherPlatformService.new(@measurement, "awekas").perform

    values = captured[:query][:val].split(";")
    assert_equal "awekas-user", values[0]
    assert_equal Digest::MD5.hexdigest("awekas-pass"), values[1]
    assert_equal "18.07.2026", values[2]
    assert_equal "12:00", values[3]
    assert_equal "20.0", values[4]
    assert_equal "-122.2285", values[-2]
    assert_equal "47.3073", values[-1]
  end

  test "update_weathercloud uses https and scaled metric values" do
    captured_url = nil
    captured = nil
    HTTParty.define_singleton_method(:get) do |url, **kwargs|
      captured_url = url
      captured = kwargs
      FakeResponse.new(code: 200, body: "OK")
    end

    UpdateThirdPartyWeatherPlatformService.new(@measurement, "weathercloud").perform

    assert_equal "https://api.weathercloud.net/v01/set", captured_url
    params = captured[:query]
    assert_equal "wc-id", params[:wid]
    assert_equal 200, params[:temp]
    assert_equal 65, params[:hum]
    assert_equal 20, params[:wspd]
    assert_equal 40, params[:wspdhi]
    assert_equal 10150, params[:bar]
  end

  test "update_cwop sends APRS login and weather packet" do
    socket = FakeSocket.new
    factory = FakeSocketFactory.new(socket)

    UpdateThirdPartyWeatherPlatformService.new(
      @measurement,
      "cwop",
      socket_factory: factory
    ).perform

    assert_equal [ [ "cwop.aprs.net", 14580 ] ], factory.opens
    assert_equal "user GW1125 pass -1 vers lhwx 1.0\r\n", socket.writes[0]
    packet = socket.writes[1]
    assert_match(/\AGW1125>APRS,TCPIP\*:@181200z/, packet)
    assert_includes packet, "4718.44N/12213.71W_"
    assert_includes packet, "h65"
    assert_includes packet, "b10132"
    assert socket.closed?
  end

  test "update_cwop throttles repeated sends within five minutes" do
    socket = FakeSocket.new
    factory = FakeSocketFactory.new(socket)
    service = UpdateThirdPartyWeatherPlatformService.new(
      @measurement,
      "cwop",
      socket_factory: factory
    )

    service.perform
    service.perform

    assert_equal 1, factory.opens.size
  end
end
