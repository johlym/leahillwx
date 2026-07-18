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
#  rain_day          :float            default(0.0), not null
#  rain_rate         :float            not null
#  reading_date_time :datetime         not null
#  soil              :jsonb            not null
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
#  index_weather_measurements_on_reading_date_time  (reading_date_time) UNIQUE
#  index_weather_measurements_on_temperature        (temperature)
#  index_weather_measurements_on_wind_speed         (wind_speed)
#
class WeatherMeasurement < ApplicationRecord
  include FeelsLike
  include HeadingToCompass

  MAX_SOIL_CHANNELS = 8

  after_create_commit :broadcast_update
  before_validation :normalize_soil

  # Validations
  # Are all the fields present?
  validates :reading_date_time, :barometer_abs, :barometer_rel, :gust_speed, :light, :humidity, :temperature, :rain_day, :rain_rate, :uv, :uvi, :wind_dir, :wind_speed, presence: true
  validates :reading_date_time, uniqueness: true

  # Are humidity, UV, wind direction integers?
  validates :humidity, :uv, :wind_dir, numericality: { only_integer: true }

  # Are barometer absolute, barometer relative, day max wind, gust speed, light, rain day, rain event, rain rate, uvi, wind speed greater than or equal to 0?
  validates :barometer_abs, :barometer_rel, :gust_speed, :light, :rain_rate, :uvi, :wind_speed, numericality: { greater_than_or_equal_to: 0 }

  validate :soil_channels_are_valid

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

  # Display-ready soil readings for SSR / ActionCable (temps in °F).
  # Channels that share a friendly name are merged into one row.
  def soil_readings
    readings = Array(soil).filter_map do |entry|
      next unless entry.is_a?(Hash)

      entry = entry.stringify_keys
      channel = Integer(entry["channel"], exception: false)
      next unless channel

      reading = {
        "channel" => channel,
        "name" => SoilChannels.name_for(channel)
      }
      reading["moisture"] = entry["moisture"].to_f.round(0) if entry["moisture"].is_a?(Numeric)
      if entry["temperature"].is_a?(Numeric)
        reading["temperature_f"] = entry["temperature"].to_fahrenheit.round(0)
      end
      reading["battery"] = entry["battery"].to_f.round(2) if entry["battery"].is_a?(Numeric)
      reading
    end

    merge_soil_readings_by_name(readings)
  end


  private

  def normalize_soil
    return if soil.nil?

    self.soil = Array(soil).map do |entry|
      hash = case entry
      when ActionController::Parameters then entry.to_unsafe_h
      when Hash then entry
      else
        entry
      end

      next hash unless hash.is_a?(Hash)

      hash = hash.stringify_keys
      normalized = { "channel" => hash["channel"] }
      normalized["moisture"] = hash["moisture"] unless hash["moisture"].nil?
      normalized["temperature"] = hash["temperature"] unless hash["temperature"].nil?
      normalized["battery"] = hash["battery"] unless hash["battery"].nil?
      normalized
    end
  end

  def soil_channels_are_valid
    return if soil.blank?

    unless soil.is_a?(Array)
      errors.add(:soil, "must be an array")
      return
    end

    if soil.size > MAX_SOIL_CHANNELS
      errors.add(:soil, "cannot have more than #{MAX_SOIL_CHANNELS} entries")
    end

    seen_channels = []

    soil.each_with_index do |entry, index|
      unless entry.is_a?(Hash)
        errors.add(:soil, "entry at index #{index} must be an object")
        next
      end

      entry = entry.stringify_keys
      channel = Integer(entry["channel"], exception: false)
      moisture = entry["moisture"]
      temperature = entry["temperature"]
      battery = entry["battery"]

      if channel.nil? || !(1..MAX_SOIL_CHANNELS).cover?(channel)
        errors.add(:soil, "channel must be an integer between 1 and #{MAX_SOIL_CHANNELS}")
      elsif seen_channels.include?(channel)
        errors.add(:soil, "channel #{channel} is duplicated")
      else
        seen_channels << channel
      end

      has_moisture = moisture.is_a?(Numeric)
      has_temperature = temperature.is_a?(Numeric)

      if !moisture.nil? && !has_moisture
        errors.add(:soil, "moisture must be a number")
      end

      if !temperature.nil? && !has_temperature
        errors.add(:soil, "temperature must be a number")
      end

      unless has_moisture || has_temperature
        errors.add(:soil, "entry must include moisture or temperature")
      end

      if !battery.nil? && !battery.is_a?(Numeric)
        errors.add(:soil, "battery must be a number")
      elsif battery.is_a?(Numeric) && battery.negative?
        errors.add(:soil, "battery must be greater than or equal to 0")
      end
    end
  end

  # Collapse channels that share a display name into one reading.
  def merge_soil_readings_by_name(readings)
    order = []
    grouped = readings.each_with_object({}) do |reading, hash|
      name = reading["name"]
      unless hash.key?(name)
        order << name
        hash[name] = []
      end
      hash[name] << reading
    end

    order.map do |name|
      channels = grouped[name].sort_by { |reading| reading["channel"] }
      merged = {
        "channel" => channels.first["channel"],
        "name" => name
      }

      moisture = channels.find { |reading| reading.key?("moisture") }&.fetch("moisture")
      temperature_f = channels.find { |reading| reading.key?("temperature_f") }&.fetch("temperature_f")
      batteries = channels.filter_map { |reading| reading["battery"] }

      merged["moisture"] = moisture unless moisture.nil?
      merged["temperature_f"] = temperature_f unless temperature_f.nil?
      merged["battery"] = batteries.min if batteries.any?

      merged
    end
  end

  def broadcast_update
    WeatherMeasurements::LiveUpdateBroadcast.call
  end
end
