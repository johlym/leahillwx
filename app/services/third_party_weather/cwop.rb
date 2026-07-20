# frozen_string_literal: true

require "socket"

module ThirdPartyWeather
  class Cwop < Base
    HOST = "cwop.aprs.net"
    PORTS = [ 14580, 23 ].freeze
    PASSCODE = "-1"
    SOCKET_TIMEOUT = 10
    MIN_INTERVAL = 10.minutes
    CACHE_KEY = "third_party_upload:cwop:last_sent_at"

    def initialize(measurement_or_id, socket_factory: TCPSocket, lock_key: nil, cwop_lock_key: nil)
      super(measurement_or_id, lock_key: lock_key || cwop_lock_key || CACHE_KEY)
      @socket_factory = socket_factory
    end

    private

    def upload(measurement)
      callsign = ENV.fetch("CWOP_CALLSIGN")
      packet = PacketBuilder.build(measurement, callsign: callsign)
      send_packet(callsign, packet)
    end

    def send_packet(callsign, packet)
      last_error = nil

      PORTS.each do |port|
        socket = nil
        begin
          socket = open_socket(port)
          read_line(socket) # server banner
          socket.write("user #{callsign} pass #{PASSCODE} vers #{SOFTWARE_TYPE} 1.0\r\n")
          read_line(socket) # login ack
          socket.write("#{packet}\r\n")
          Rails.logger.info "[#{service_name}] success via #{HOST}:#{port}: #{packet}"
          return
        rescue StandardError => e
          last_error = e
          Rails.logger.warn "[#{service_name}] send via #{HOST}:#{port} failed: #{e.message}"
        ensure
          socket&.close
        end
      end

      raise last_error if last_error
    end

    def open_socket(port)
      socket = @socket_factory.open(HOST, port, connect_timeout: SOCKET_TIMEOUT)
      socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1) if socket.respond_to?(:setsockopt)
      socket.timeout = SOCKET_TIMEOUT if socket.respond_to?(:timeout=)
      socket
    end

    def read_line(socket)
      return unless socket.respond_to?(:gets)

      socket.gets
    end

    def service_name
      "cwop"
    end

    def required_env
      %w[CWOP_CALLSIGN LOCATION_LAT LOCATION_LON]
    end

    def min_interval
      MIN_INTERVAL
    end
  end
end
