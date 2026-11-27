# frozen_string_literal: true

require "digest"

module ThirdPartyWeather
  # AWEKAS semicolon-delimited GET.
  # Rain is millimeters since local midnight and mm/h. weewx multiplies those
  # fields by 10; AWEKAS stores the number as mm, so that scale is 10x too high.
  # Solar radiation is W/m². The station light register is lux (brightness).
  class Awekas < Base
    URL = "https://data.awekas.at/eingabe_pruefung.php"
    MIN_INTERVAL = 5.minutes

    private

    def upload(measurement)
      password_hash = Digest::MD5.hexdigest(ENV.fetch("AWEKAS_PASSWORD"))
      time_utc = measurement.reading_date_time.utc
      solar_wm2 = WeatherMeasurement.lux_to_solar_irradiance_wm2(measurement.light)

      values = [
        ENV.fetch("AWEKAS_USERNAME"),
        password_hash,
        time_utc.strftime("%d.%m.%Y"),
        time_utc.strftime("%H:%M"),
        measurement.temperature,
        measurement.humidity,
        measurement.sea_level_pressure_qff&.round(1), # QFF hPa; AWEKAS QC vs neighbors
        measurement.rain_day.round(2), # mm since local midnight
        (measurement.wind_speed * 3.6).round(1), # m/s to km/h
        measurement.wind_dir,
        "", # weather condition
        "", # warning text
        "", # snow height
        "en", # language
        "", # tendency
        (measurement.gust_speed * 3.6).round(1), # m/s to km/h
        solar_wm2&.round(1), # W/m²
        measurement.uvi,
        measurement.light.round(0), # lux
        "", # sunshine hours
        "", # soil temperature
        measurement.rain_rate.round(2), # mm/h
        SOFTWARE_TYPE,
        ENV.fetch("LOCATION_LON"),
        ENV.fetch("LOCATION_LAT")
      ]

      response = HTTParty.get(URL, query: { val: values.join(";") }, timeout: HTTP_TIMEOUT)
      log_response(response)
    end

    def log_response(response)
      code = response.code.to_i
      body = sanitize_response_body(response.body)

      if code.between?(200, 299) && body.match?(/\AOK/i)
        log_http_success(code, body)
      elsif body.match?(/Benutzer\/Passwort Fehler/i)
        Rails.logger.error "[#{service_name}] auth failed (HTTP #{code}): #{body}"
      else
        log_http_failure(code, body.presence || "(empty body)")
      end
    end

    def service_name
      "awekas"
    end

    def required_env
      %w[AWEKAS_USERNAME AWEKAS_PASSWORD LOCATION_LAT LOCATION_LON]
    end

    def min_interval
      MIN_INTERVAL
    end
  end
end
