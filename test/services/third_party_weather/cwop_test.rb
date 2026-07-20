# frozen_string_literal: true

require "test_helper"

module ThirdPartyWeather
  class CwopTest < ActiveSupport::TestCase
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

      ENV["CWOP_CALLSIGN"] = "GW1125"
      ENV["LOCATION_LAT"] = "47.3073"
      ENV["LOCATION_LON"] = "-122.2285"

      @lock_key = "third_party_upload:cwop:test:#{SecureRandom.hex(16)}"
      clear_throttle!
    end

    teardown do
      %w[CWOP_CALLSIGN LOCATION_LAT LOCATION_LON].each { |key| ENV.delete(key) }
      clear_throttle!
    end

    def clear_throttle!
      return if @lock_key.blank?

      Sidekiq.redis { |conn| conn.del(@lock_key) }
    end

    def cwop_service(measurement, socket_factory: FakeSocketFactory.new(FakeSocket.new))
      Cwop.new(measurement, socket_factory: socket_factory, lock_key: @lock_key)
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
      clear_throttle!
      cwop_service(measurement, socket_factory: socket_factory).call
      socket_factory.socket.writes[1]
    end

    test "sends APRS login and weather packet" do
      socket = FakeSocket.new
      factory = FakeSocketFactory.new(socket)

      cwop_service(@measurement, socket_factory: factory).call

      assert_equal [ [ "cwop.aprs.net", 14580 ] ], factory.opens
      assert_equal(
        [ { connect_timeout: Cwop::SOCKET_TIMEOUT } ],
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

    test "does not release lock when claim raises" do
      Sidekiq.redis do |conn|
        conn.set(@lock_key, "other-worker", nx: true, ex: 300)
      end

      claim_calls = 0
      service = cwop_service(@measurement)
      service.define_singleton_method(:claim_send_slot!) do
        claim_calls += 1
        raise RedisClient::Error, "redis unavailable"
      end

      assert_raises(RedisClient::Error) { service.call }
      assert_equal 1, claim_calls
      assert_equal "other-worker", Sidekiq.redis { |conn| conn.get(@lock_key) }
    end

    test "throttles repeated sends within ten minutes" do
      socket = FakeSocket.new
      factory = FakeSocketFactory.new(socket)
      service = cwop_service(@measurement, socket_factory: factory)

      service.call
      service.call

      assert_equal 1, factory.opens.size
    end

    test "claim is atomic across concurrent callers" do
      barrier = Queue.new
      results = Queue.new

      threads = 2.times.map do
        Thread.new do
          barrier.pop
          socket = FakeSocket.new
          factory = FakeSocketFactory.new(socket)
          cwop_service(@measurement, socket_factory: factory).call
          results << factory.opens.size
        end
      end

      2.times { barrier << true }
      threads.each(&:join)

      assert_equal 1, Array.new(2) { results.pop }.sum
    end

    test "humidity encodes 100 as h00 and 0 as h01" do
      WeatherMeasurement.delete_all
      humid_100 = create_reading_at(Time.utc(2026, 7, 18, 13, 0, 0), rain_day: 0.0, humidity: 100)
      humid_0 = create_reading_at(Time.utc(2026, 7, 18, 13, 1, 0), rain_day: 0.0, humidity: 0)

      assert_includes cwop_packet_for(humid_100), "h00"
      assert_includes cwop_packet_for(humid_0), "h01"
    end

    test "temperature uses fixed-width negative encoding" do
      WeatherMeasurement.delete_all
      # -25 C => -13 F; APRS field must be exactly three chars: "-13"
      cold = create_reading_at(Time.utc(2026, 7, 18, 13, 0, 0), rain_day: 0.0, temperature: -25.0)

      packet = cwop_packet_for(cold)
      assert_match(/t-13/, packet)
      assert_match(/t-13r/, packet)
    end

    test "hour rain uses baseline before window and sums across midnight" do
      WeatherMeasurement.delete_all
      # Times chosen so the drop crosses America/Los_Angeles midnight.
      # 06:30 UTC = 23:30 PT previous evening; 07:10 UTC = 00:10 PT.
      create_reading_at(Time.utc(2026, 7, 18, 6, 30, 0), rain_day: 5.08)
      create_reading_at(Time.utc(2026, 7, 18, 6, 50, 0), rain_day: 7.62) # +0.10"
      create_reading_at(Time.utc(2026, 7, 18, 7, 10, 0), rain_day: 1.27) # midnight reset + 0.05"
      latest = create_reading_at(Time.utc(2026, 7, 18, 7, 30, 0), rain_day: 3.81) # +0.10"

      # Window 06:30→07:30 UTC: 0.10 + 0.05 + 0.10 = 0.25" => r025
      packet = cwop_packet_for(latest)
      assert_match(/r025/, packet)
    end

    test "hour rain ignores same-day rain_day decreases" do
      WeatherMeasurement.delete_all
      create_reading_at(Time.utc(2026, 7, 18, 15, 0, 0), rain_day: 5.08)
      create_reading_at(Time.utc(2026, 7, 18, 15, 20, 0), rain_day: 1.27) # glitch drop, same local day
      latest = create_reading_at(Time.utc(2026, 7, 18, 15, 40, 0), rain_day: 2.54) # +0.05"

      # Only the post-glitch increase counts: 0.05" => r005
      packet = cwop_packet_for(latest)
      assert_match(/r005/, packet)
    end

    test "hour rain prorates baseline segment to exclude pre-window rain" do
      WeatherMeasurement.delete_all
      # Baseline an hour before the window; half of the first segment is pre-window.
      create_reading_at(Time.utc(2026, 7, 18, 11, 0, 0), rain_day: 0.0)
      create_reading_at(Time.utc(2026, 7, 18, 12, 0, 0), rain_day: 2.54) # +0.10" over 60m
      latest = create_reading_at(Time.utc(2026, 7, 18, 12, 30, 0), rain_day: 5.08) # +0.10"

      # Window 11:30→12:30: half of first 0.10" (0.05) + 0.10" = 0.15" => r015
      packet = cwop_packet_for(latest)
      assert_match(/r015/, packet)
    end

    test "rain fields are zero without prior history instead of using rain rate" do
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

    test "24h rain sums rolling window not just rain_day" do
      WeatherMeasurement.delete_all
      # Cross PT midnight between 06:50 UTC (23:50 PT) and 07:20 UTC (00:20 PT).
      create_reading_at(Time.utc(2026, 7, 17, 12, 0, 0), rain_day: 2.54)
      create_reading_at(Time.utc(2026, 7, 18, 6, 50, 0), rain_day: 5.08) # +0.10 before midnight
      create_reading_at(Time.utc(2026, 7, 18, 7, 20, 0), rain_day: 1.27) # reset + 0.05
      latest = create_reading_at(Time.utc(2026, 7, 18, 12, 0, 0), rain_day: 2.54) # +0.05

      # 24h window: 0.10 + 0.05 + 0.05 = 0.20" => p020
      packet = cwop_packet_for(latest)
      assert_match(/p020/, packet)
    end
  end
end
