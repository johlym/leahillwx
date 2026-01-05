class WeatherMeasurement < ApplicationRecord
  after_create_commit :broadcast_update

  # Validations
  # Are all the fields present?
  validates :reading_date_time, :barometer_abs, :barometer_rel, :day_max_wind, :gust_speed, :light, :humidity, :temperature, :rain_day, :rain_event, :rain_rate, :uv, :uvi, :wind_dir, :wind_speed, presence: true

  # Are humidity, UV, wind direction integers?
  validates :humidity, :uv, :wind_dir, numericality: { only_integer: true }

  # Are barometer absolute, barometer relative, day max wind, gust speed, light, rain day, rain event, rain rate, uvi, wind speed greater than or equal to 0?
  validates :barometer_abs, :barometer_rel, :day_max_wind, :gust_speed, :light, :rain_day, :rain_event, :rain_rate, :uvi, :wind_speed, numericality: { greater_than_or_equal_to: 0 }

  def barometer_abs_mmhg
    barometer_abs * 3.38637526
  end

  def barometer_rel_mmhg
    barometer_rel * 3.38637526
  end

  def day_max_wind_kmph
    day_max_wind * 1.60934
  end

  def gust_speed_kmph
    gust_speed * 1.60934
  end

  def wind_speed_kmph
    wind_speed * 1.60934
  end

  def temperature_f
    ((temperature * 9 / 5) + 32).round(2)
  end

  def rain_day_in
    rain_day * 25.4
  end

  def rain_event_in
    rain_event * 25.4
  end

  def rain_rate_in
    rain_rate * 25.4
  end

  def friendly_reading_date_time
    reading_date_time.strftime("%B %d, %Y %I:%M %p %Z")
  end

  private

  def broadcast_update
    Turbo::StreamsChannel.broadcast_replace_to(
      "weather_measurements",
      target: "current_weather",
      partial: "root/current_weather",
      locals: { current: self }
    )
  end
end
