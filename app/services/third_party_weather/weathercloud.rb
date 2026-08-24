# frozen_string_literal: true

module ThirdPartyWeather
  # WeatherCloud API v01 (scaled metric). See weathercloud / weewx-wcloud docs.
  class Weathercloud < Base
    URL = "https://api.weathercloud.net/v01/set"
    MIN_INTERVAL = 10.minutes

    STATUS_MESSAGES = {
      200 => "success",
      400 => "bad request",
      401 => "incorrect WID or key",
      429 => "too many requests (rate limited)",
      500 => "server error"
    }.freeze

    private

    def upload(measurement)
      params = {
        wid: ENV.fetch("WEATHERCLOUD_DEVICE_ID"),
        key: ENV.fetch("WEATHERCLOUD_DEVICE_KEY")
      }

      params[:temp] = (measurement.temperature * 10).round(0) if measurement.temperature
      params[:hum] = measurement.humidity.round(0) if measurement.humidity
      params[:tempin] = (measurement.temperature * 10).round(0) if measurement.temperature

      params[:wspd] = (measurement.wind_speed * 10).round(0) if measurement.wind_speed
      params[:wdir] = measurement.wind_dir.round(0) if measurement.wind_dir
      params[:wspdhi] = (measurement.gust_speed * 10).round(0) if measurement.gust_speed

      params[:bar] = (measurement.sea_level_pressure * 10).round(0) if measurement.sea_level_pressure

      params[:rain] = (measurement.rain_day * 10).round(0) if measurement.rain_day
      params[:rainrate] = (measurement.rain_rate * 10).round(0) if measurement.rain_rate

      params[:solarrad] = (measurement.light * 10).round(0) if measurement.light
      params[:uvi] = (measurement.uvi * 10).round(0) if measurement.uvi

      if measurement.dew_point
        params[:dew] = (measurement.dew_point * 10).round(0)
      end

      if measurement.feels_like
        params[:heat] = (measurement.feels_like * 10).round(0)
      end

      response = HTTParty.get(URL, query: params, timeout: HTTP_TIMEOUT)
      log_response(response)
    end

    def log_response(response)
      code = response.code.to_i
      meaning = STATUS_MESSAGES[code] || "unexpected status"
      body = sanitize_response_body(response.body)

      if code == 200
        Rails.logger.info "[#{service_name}] success (HTTP #{code}: #{meaning})"
      else
        detail = body.present? && body != code.to_s ? " body=#{body}" : ""
        Rails.logger.error "[#{service_name}] failed (HTTP #{code}: #{meaning})#{detail}"
      end
    end

    def service_name
      "weathercloud"
    end

    def required_env
      %w[WEATHERCLOUD_DEVICE_ID WEATHERCLOUD_DEVICE_KEY]
    end

    def min_interval
      MIN_INTERVAL
    end
  end
end
