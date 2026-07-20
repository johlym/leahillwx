# frozen_string_literal: true

module ThirdPartyWeather
  class Cwop
    class PacketBuilder
      def self.build(measurement, callsign:)
        new(measurement, callsign: callsign).build
      end

      def initialize(measurement, callsign:)
        @measurement = measurement
        @callsign = callsign
      end

      def build
        lat = ENV.fetch("LOCATION_LAT").to_f
        lon = ENV.fetch("LOCATION_LON").to_f
        time_utc = @measurement.reading_date_time.utc

        timestamp = time_utc.strftime("%d%H%Mz")
        position = "#{format_aprs_latitude(lat)}/#{format_aprs_longitude(lon)}"

        wind_dir = format("%03d", @measurement.wind_dir.round.clamp(0, 360) % 360)
        wind_speed = format("%03d", @measurement.wind_speed_mph.round.clamp(0, 999))
        gust = format("%03d", @measurement.gust_speed_mph.round.clamp(0, 999))
        temp_f = format_temperature(@measurement.temperature.to_fahrenheit)
        rain_hour = format("%03d", (rain_last_hour_inches * 100).round.clamp(0, 999))
        rain_24h = format("%03d", (rain_last_24h_inches * 100).round.clamp(0, 999))
        rain_day = format("%03d", (@measurement.rain_day_in * 100).round.clamp(0, 999))
        humidity = format_humidity(@measurement.humidity)
        pressure = format("%05d", (@measurement.barometer_abs * 10).round.clamp(0, 99_999))

        weather = "#{wind_dir}/#{wind_speed}g#{gust}t#{temp_f}r#{rain_hour}p#{rain_24h}P#{rain_day}h#{humidity}b#{pressure}"

        "#{@callsign}>APRS,TCPIP*:@#{timestamp}#{position}_#{weather}"
      end

      private

      # APRS weather temperature is a fixed 3-character field: "068" or "-13".
      def format_temperature(temp_f)
        value = temp_f.round.clamp(-99, 999)
        return format("-%02d", value.abs) if value.negative?

        format("%03d", value)
      end

      # APRS encodes 100% RH as h00. True 0% cannot be represented, so use h01.
      def format_humidity(humidity)
        value = humidity.to_i
        return "00" if value >= 100
        return "01" if value <= 0

        format("%02d", value)
      end

      def format_aprs_latitude(lat)
        hemisphere = lat >= 0 ? "N" : "S"
        abs_lat = lat.abs
        degrees = abs_lat.floor
        minutes = (abs_lat - degrees) * 60.0
        format("%02d%05.2f%s", degrees, minutes, hemisphere)
      end

      def format_aprs_longitude(lon)
        hemisphere = lon >= 0 ? "E" : "W"
        abs_lon = lon.abs
        degrees = abs_lon.floor
        minutes = (abs_lon - degrees) * 60.0
        format("%03d%05.2f%s", degrees, minutes, hemisphere)
      end

      def rain_last_hour_inches
        RainWindow.inches(since: @measurement.reading_date_time - 1.hour, through: @measurement)
      end

      def rain_last_24h_inches
        RainWindow.inches(since: @measurement.reading_date_time - 24.hours, through: @measurement)
      end
    end
  end
end
