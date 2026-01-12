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
    feels_like_c(temp_c: temperature, humidity: humidity, wind_speed_mps: wind_speed)
  end

  def heading_compass
    heading_to_compass
  end

  def friendly_reading_date_time
    reading_date_time.in_time_zone("America/Los_Angeles").strftime("%B %d, %Y %I:%M:%S %p %Z")
  end

  private

  def broadcast_update
    Turbo::StreamsChannel.broadcast_update_to(
      "weather_measurements",
      target: "current_weather",
      html: render_current_weather_html
    )
  end

  def render_current_weather_html
    ApplicationController.render(
      partial: "root/current_weather",
      locals: { current: self }
    )
  end
end
