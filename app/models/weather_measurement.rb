# == Schema Information
#
# Table name: weather_measurements
#
#  id                :bigint           not null, primary key
#  barometer_abs     :float            not null
#  barometer_rel     :float            not null
#  gust_speed        :float            not null
#  humidity          :integer          not null
#  light             :float            not null
#  rain_day          :float            default(0.0)
#  rain_rate         :float            not null
#  reading_date_time :datetime         not null
#  temperature       :float            not null
#  uv                :integer          not null
#  uvi               :float            not null
#  wind_dir          :integer          not null
#  wind_speed        :float            not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_weather_measurements_on_barometer_rel      (barometer_rel)
#  index_weather_measurements_on_gust_speed         (gust_speed)
#  index_weather_measurements_on_humidity           (humidity)
#  index_weather_measurements_on_light              (light)
#  index_weather_measurements_on_rain_day           (rain_day)
#  index_weather_measurements_on_rain_rate          (rain_rate)
#  index_weather_measurements_on_reading_date_time  (reading_date_time)
#  index_weather_measurements_on_temperature        (temperature)
#  index_weather_measurements_on_wind_speed         (wind_speed)
#
class WeatherMeasurement < ApplicationRecord
  include FeelsLike
  include HeadingToCompass
  after_create_commit :broadcast_update

  # Validations
  # Are all the fields present?
  validates :reading_date_time, :barometer_abs, :barometer_rel, :gust_speed, :light, :humidity, :temperature, :rain_day, :rain_rate, :uv, :uvi, :wind_dir, :wind_speed, presence: true

  # Are humidity, UV, wind direction integers?
  validates :humidity, :uv, :wind_dir, numericality: { only_integer: true }

  # Are barometer absolute, barometer relative, day max wind, gust speed, light, rain day, rain event, rain rate, uvi, wind speed greater than or equal to 0?
  validates :barometer_abs, :barometer_rel, :gust_speed, :light, :rain_rate, :uvi, :wind_speed, numericality: { greater_than_or_equal_to: 0 }

  def barometer_abs_mmhg
    barometer_abs * 3.38637526
  end

  def barometer_rel_mmhg
    barometer_rel * 3.38637526
  end

  # meters/second to miles/hour
  def gust_speed_mph
    gust_speed * 2.23694
  end

  # meters/second to miles/hour
  def wind_speed_mph
    wind_speed * 2.23694
  end

  # millimeters total to inch total
  def rain_day_in
    rain_day / 25.4
  end

  # millimeters/hour to inch/hour
  def rain_rate_in
    rain_rate / 25.4
  end

  # Dew point: Td = T - [(100 - RH)/5], where Td is dew point, T is temperature, and RH is relative humidity (in Celsius/percent)
  def dew_point
    temperature - ((100 - humidity) / 5.0)
  end

  def feels_like
    feels_like_c(
      temp_c: temperature,
      humidity: humidity,
      wind_speed_mps: wind_speed,
      cloud_pct: current_cloud_cover,
      is_daytime: daytime?
    )
  end

  def current_cloud_cover
    current_forecast = Forecast.where(interval: "current").order(created_at: :desc).first
    return 50.0 unless current_forecast

    forecast_data = current_forecast.forecast.deep_symbolize_keys
    forecast_data.dig(:current, :clouds) || 50.0
  end

  def daytime?
    almanac = AlmanacEntry.find_by(date: reading_date_time.in_time_zone("America/Los_Angeles").to_date)
    return false unless almanac&.sunrise_at && almanac&.sunset_at

    reading_date_time.between?(almanac.sunrise_at, almanac.sunset_at)
  end

  def heading_compass
    heading_to_compass
  end

  def friendly_reading_date_time
    reading_date_time.in_time_zone("America/Los_Angeles").strftime("%B %d, %Y %I:%M:%S %p %Z")
  end

  private

  def broadcast_update
    current_with_count = WeatherMeasurement
      .select("weather_measurements.*, (SELECT COUNT(*) FROM weather_measurements) as total_count")
      .order(reading_date_time: :desc)
      .first

    return unless current_with_count

    data_json = weather_data_json(current_with_count).to_json
    turbo_stream_html = %(<turbo-stream action="weather_update" data="#{CGI.escapeHTML(data_json)}"><template></template></turbo-stream>)

    ActionCable.server.broadcast(
      "weather_measurements",
      turbo_stream_html
    )
  rescue StandardError => e
    Rails.logger.error("Failed to broadcast weather update: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
  end

  def weather_data_json(measurement)
    {
      temperature_f: ActionController::Base.helpers.number_with_precision(
        measurement.temperature.to_fahrenheit, precision: 2, strip_insignificant_zeros: true
      ),
      feels_like_f: ActionController::Base.helpers.number_with_precision(
        measurement.feels_like.to_fahrenheit, precision: 2, strip_insignificant_zeros: true
      ),
      counter: measurement.total_count,
      wind_speed_mph: ActionController::Base.helpers.number_with_precision(
        measurement.wind_speed_mph, precision: 2, strip_insignificant_zeros: true
      ),
      wind_direction_compass: measurement.heading_compass,
      wind_direction_deg: measurement.wind_dir,
      gust_speed_mph: ActionController::Base.helpers.number_with_precision(
        measurement.gust_speed_mph, precision: 2, strip_insignificant_zeros: true
      ),
      rain_day_in: ActionController::Base.helpers.number_with_precision(
        measurement.rain_day_in, precision: 2, strip_insignificant_zeros: true
      ),
      rain_rate_in: ActionController::Base.helpers.number_with_precision(
        measurement.rain_rate_in, precision: 2, strip_insignificant_zeros: true
      ),
      dew_point_f: ActionController::Base.helpers.number_with_precision(
        measurement.dew_point.to_fahrenheit, precision: 2, strip_insignificant_zeros: true
      ),
      humidity: measurement.humidity,
      barometer_abs_mb: ActionController::Base.helpers.number_with_precision(
        measurement.barometer_abs, precision: 2, strip_insignificant_zeros: true
      ),
      uv: ActionController::Base.helpers.number_with_precision(
        measurement.uv, precision: 2, strip_insignificant_zeros: true
      ),
      uvi: ActionController::Base.helpers.number_with_precision(
        measurement.uvi, precision: 2, strip_insignificant_zeros: true
      ),
      light_lux: ActionController::Base.helpers.number_with_delimiter(
        ActionController::Base.helpers.number_with_precision(
          measurement.light, precision: 2, strip_insignificant_zeros: true
        )
      )
    }
  end
end
