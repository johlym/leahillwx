class WeatherMeasurement < ApplicationRecord
  # Validations
  # Are all the fields present?
  validates :reading_date_time, :barometer_abs, :barometer_rel, :day_max_wind, :gust_speed, :light, :humidity, :temperature, :rain_day, :rain_event, :rain_rate, :uv, :uvi, :wind_dir, :wind_speed, presence: true

  # Are humidity, UV, wind direction integers?
  validates :humidity, :uv, :wind_dir, numericality: { only_integer: true }

  # Are barometer absolute, barometer relative, day max wind, gust speed, light, rain day, rain event, rain rate, uvi, wind speed greater than or equal to 0?
  validates :barometer_abs, :barometer_rel, :day_max_wind, :gust_speed, :light, :rain_day, :rain_event, :rain_rate, :uvi, :wind_speed, numericality: { greater_than_or_equal_to: 0 }
end
