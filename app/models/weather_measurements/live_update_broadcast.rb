# frozen_string_literal: true

module WeatherMeasurements
  class LiveUpdateBroadcast
    def self.call
      new.call
    end

    def call
      current_with_count = WeatherMeasurement
        .select("weather_measurements.*, (SELECT COUNT(*) FROM weather_measurements) as total_count")
        .order(reading_date_time: :desc)
        .first

      return unless current_with_count

      data_json = payload(current_with_count).to_json
      turbo_stream_html = %(<turbo-stream action="weather_update" data="#{CGI.escapeHTML(data_json)}"><template></template></turbo-stream>)

      ActionCable.server.broadcast("weather_measurements", turbo_stream_html)
    rescue StandardError => e
      Rails.logger.error("Failed to broadcast weather update: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
    end

    private

    def payload(measurement)
      helpers = ActionController::Base.helpers

      {
        temperature_f: helpers.number_with_precision(
          measurement.temperature.to_fahrenheit, precision: 2, strip_insignificant_zeros: true
        ),
        feels_like_f: helpers.number_with_precision(
          measurement.feels_like.to_fahrenheit, precision: 2, strip_insignificant_zeros: true
        ),
        counter: measurement.total_count,
        wind_speed_mph: helpers.number_with_precision(
          measurement.wind_speed_mph, precision: 2, strip_insignificant_zeros: true
        ),
        wind_direction_compass: measurement.heading_compass,
        wind_direction_deg: measurement.wind_dir,
        gust_speed_mph: helpers.number_with_precision(
          measurement.gust_speed_mph, precision: 2, strip_insignificant_zeros: true
        ),
        rain_day_in: helpers.number_with_precision(
          measurement.rain_day_in, precision: 2, strip_insignificant_zeros: true
        ),
        rain_rate_in: helpers.number_with_precision(
          measurement.rain_rate_in, precision: 2, strip_insignificant_zeros: true
        ),
        dew_point_f: helpers.number_with_precision(
          measurement.dew_point.to_fahrenheit, precision: 2, strip_insignificant_zeros: true
        ),
        humidity: measurement.humidity,
        barometer_abs_mb: helpers.number_with_precision(
          measurement.barometer_abs, precision: 2, strip_insignificant_zeros: true
        ),
        uv: helpers.number_with_precision(
          measurement.uv, precision: 2, strip_insignificant_zeros: true
        ),
        uvi: helpers.number_with_precision(
          measurement.uvi, precision: 2, strip_insignificant_zeros: true
        ),
        light_lux: helpers.number_with_delimiter(
          helpers.number_with_precision(
            measurement.light, precision: 2, strip_insignificant_zeros: true
          )
        ),
        soil: measurement.soil_readings,
        sparklines: WeatherData::LiveCardHourlyRanges.new.call
      }
    end
  end
end
