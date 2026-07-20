# frozen_string_literal: true

module ThirdPartyWeather
  # Ambient / Weather Underground PWS upload protocol (shared by WU and PWSWeather).
  # See weewx restx AmbientThread.
  class Ambient
    # dateutc must be "YYYY-MM-DD HH:MM:SS" (UTC).
    # HTTParty query encoding turns the space into +/%20 — do NOT put a literal "+"
    # in the value (that becomes %2B and providers reject it).
    def self.dateutc(measurement)
      measurement.reading_date_time.utc.strftime("%Y-%m-%d %H:%M:%S")
    end

    def self.get(url:, station_id:, password:, measurement:, include_weather_clouds:, service_name:)
      date_utc = dateutc(measurement)

      request_params = {
        ID: station_id,
        PASSWORD: password,
        dateutc: date_utc,
        winddir: measurement.wind_dir,
        windspeedmph: measurement.wind_speed_mph.round(2),
        windgustmph: measurement.gust_speed_mph.round(2),
        tempf: measurement.temperature.to_fahrenheit.round(2),
        rainin: measurement.rain_rate_in.round(4),
        dailyrainin: measurement.rain_day_in.round(4),
        baromin: measurement.barometer_rel_inhg.round(3),
        dewptf: measurement.dew_point.to_fahrenheit.round(2),
        humidity: measurement.humidity,
        softwaretype: Base::SOFTWARE_TYPE,
        action: "updateraw"
      }

      if include_weather_clouds
        request_params[:weather] = ""
        request_params[:clouds] = ""
      end

      Rails.logger.info "[#{service_name}] dateutc=#{date_utc}"
      response = HTTParty.get(url, query: request_params, timeout: Base::HTTP_TIMEOUT)
      log_response(response, service_name: service_name)
    end

    def self.log_response(response, service_name:)
      code = response.code.to_i
      body = Base.sanitize_response_body(response.body)
      detail = body.presence || "(empty body)"

      if success?(code, body)
        Rails.logger.info "[#{service_name}] success (HTTP #{code}): #{detail}"
      else
        Rails.logger.error "[#{service_name}] failed (HTTP #{code}): #{detail}"
      end
    end

    def self.success?(code, body)
      return false unless code.between?(200, 299)

      normalized = body.to_s.strip
      return false if normalized.match?(/\AERROR/i)
      return false if normalized.match?(/bad request/i)
      return false if normalized.match?(/invalid/i)

      true
    end
    private_class_method :success?
  end
end
