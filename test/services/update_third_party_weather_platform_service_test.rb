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
    attr_reader :opens, :socket, :open_options

    def initialize(socket)
      @socket = socket
      @opens = []
      @open_options = []
    end

    def open(host, port, **options)
      opens << [ host, port ]
      open_options << options
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

    # Unique lock key per test so parallel test workers cannot clear each other's Redis claim.
    @cwop_lock_key = "third_party_upload:cwop:test:#{SecureRandom.hex(16)}"
    clear_cwop_throttle!
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

    clear_cwop_throttle!
  end

  def clear_cwop_throttle!
    return if @cwop_lock_key.blank?

    Sidekiq.redis { |conn| conn.del(@cwop_lock_key) }
  end

  def cwop_service(measurement, socket_factory: FakeSocketFactory.new(FakeSocket.new))
    UpdateThirdPartyWeatherPlatformService.new(
      measurement,
      "cwop",
      socket_factory: socket_factory,
      cwop_lock_key: @cwop_lock_key
    )
  end

  def create_reading_at(time, rain_day:, **overrides)
    WeatherMeasurement.create!(
      {
        reading_date_time: time,
        barometer_abs: 1013.2,
        barometer_rel: 1015.0,
        gust_speed: 2.0,
        light: 100.0,
        humidity: 50,
        temperature: 18.0,
        rain_day: rain_day,
        rain_rate: 0.0,
        uv: 1,
        uvi: 1.0,
        wind_dir: 90,
        wind_speed: 1.0
      }.merge(overrides)
    )
  end

  def cwop_packet_for(measurement, socket_factory: FakeSocketFactory.new(FakeSocket.new))
    clear_cwop_throttle!
    cwop_service(measurement, socket_factory: socket_factory).perform
    socket_factory.socket.writes[1]
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

    cwop_service(@measurement, socket_factory: factory).perform

    assert_equal [ [ "cwop.aprs.net", 14580 ] ], factory.opens
    assert_equal(
      [ { connect_timeout: UpdateThirdPartyWeatherPlatformService::CWOP_SOCKET_TIMEOUT } ],
      factory.open_options
    )
    assert_equal "user GW1125 pass -1 vers lhwx 1.0\r\n", socket.writes[0]
    packet = socket.writes[1]
    assert_match(/\AGW1125>APRS,TCPIP\*:@181200z/, packet)
    assert_includes packet, "4718.44N/12213.71W_"
    assert_includes packet, "h65"
    assert_includes packet, "b10132"
    assert socket.closed?
  end

  test "update_cwop does not release lock when claim raises" do
    Sidekiq.redis do |conn|
      conn.set(@cwop_lock_key, "other-worker", nx: true, ex: 300)
    end

    claim_calls = 0
    service = cwop_service(@measurement)
    service.define_singleton_method(:claim_cwop_send_slot!) do
      claim_calls += 1
      raise RedisClient::Error, "redis unavailable"
    end

    assert_raises(RedisClient::Error) { service.perform }
    assert_equal 1, claim_calls
    assert_equal "other-worker", Sidekiq.redis { |conn| conn.get(@cwop_lock_key) }
  end

  test "update_cwop throttles repeated sends within five minutes" do
    socket = FakeSocket.new
    factory = FakeSocketFactory.new(socket)
    service = cwop_service(@measurement, socket_factory: factory)

    service.perform
    service.perform

    assert_equal 1, factory.opens.size
  end

  test "update_cwop claim is atomic across concurrent callers" do
    barrier = Queue.new
    results = Queue.new

    threads = 2.times.map do
      Thread.new do
        barrier.pop
        socket = FakeSocket.new
        factory = FakeSocketFactory.new(socket)
        cwop_service(@measurement, socket_factory: factory).perform
        results << factory.opens.size
      end
    end

    2.times { barrier << true }
    threads.each(&:join)

    assert_equal 1, Array.new(2) { results.pop }.sum
  end

  test "CWOP humidity encodes 100 as h00 and 0 as h01" do
    WeatherMeasurement.delete_all
    humid_100 = create_reading_at(Time.utc(2026, 7, 18, 13, 0, 0), rain_day: 0.0, humidity: 100)
    humid_0 = create_reading_at(Time.utc(2026, 7, 18, 13, 1, 0), rain_day: 0.0, humidity: 0)

    assert_includes cwop_packet_for(humid_100), "h00"
    assert_includes cwop_packet_for(humid_0), "h01"
  end

  test "CWOP hour rain uses baseline before window and sums across midnight" do
    WeatherMeasurement.delete_all
    # 11:30 previous "day" counter, then midnight reset, then more rain.
    create_reading_at(Time.utc(2026, 7, 18, 11, 30, 0), rain_day: 5.08) # 0.20"
    create_reading_at(Time.utc(2026, 7, 18, 11, 50, 0), rain_day: 7.62) # +0.10"
    create_reading_at(Time.utc(2026, 7, 18, 12, 5, 0), rain_day: 1.27)  # reset + 0.05"
    latest = create_reading_at(Time.utc(2026, 7, 18, 12, 30, 0), rain_day: 3.81) # +0.10"

    # Window is 11:30→12:30: 0.10 (before midnight) + 0.05 + 0.10 = 0.25" => r025
    packet = cwop_packet_for(latest)
    assert_match(/r025/, packet)
  end

  test "CWOP hour rain prorates baseline segment to exclude pre-window rain" do
    WeatherMeasurement.delete_all
    # Baseline an hour before the window; half of the first segment is pre-window.
    create_reading_at(Time.utc(2026, 7, 18, 11, 0, 0), rain_day: 0.0)
    create_reading_at(Time.utc(2026, 7, 18, 12, 0, 0), rain_day: 2.54) # +0.10" over 60m
    latest = create_reading_at(Time.utc(2026, 7, 18, 12, 30, 0), rain_day: 5.08) # +0.10"

    # Window 11:30→12:30: half of first 0.10" (0.05) + 0.10" = 0.15" => r015
    packet = cwop_packet_for(latest)
    assert_match(/r015/, packet)
  end

  test "CWOP rain fields are zero without prior history instead of using rain rate" do
    WeatherMeasurement.delete_all
    sparse = create_reading_at(
      Time.utc(2026, 7, 18, 14, 0, 0),
      rain_day: 12.7,
      rain_rate: 25.4 # 1.0 in/hr — must not become r100
    )

    packet = cwop_packet_for(sparse)
    assert_match(/r000/, packet)
    assert_match(/p000/, packet)
  end

  test "CWOP 24h rain sums rolling window not just rain_day" do
    WeatherMeasurement.delete_all
    create_reading_at(Time.utc(2026, 7, 17, 13, 0, 0), rain_day: 2.54)
    create_reading_at(Time.utc(2026, 7, 17, 18, 0, 0), rain_day: 5.08) # +0.10 yesterday
    create_reading_at(Time.utc(2026, 7, 18, 1, 0, 0), rain_day: 1.27)  # reset + 0.05
    latest = create_reading_at(Time.utc(2026, 7, 18, 12, 0, 0), rain_day: 2.54) # +0.05

    # 24h window from 12:00 previous day: 0.10 + 0.05 + 0.05 = 0.20" => p020
    packet = cwop_packet_for(latest)
    assert_match(/p020/, packet)
  end
end
