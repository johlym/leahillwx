# frozen_string_literal: true

class Home::CurrentWeather::ConditionsComponent < ViewComponent::Base
  def initialize(current:, almanac:, today_forecast: nil, current_forecast: nil)
    @current = current
    @almanac = almanac
    @today_forecast = today_forecast
    @current_forecast = current_forecast
  end

  def season
    @almanac.season
  end

  def current_temperature
    @current.temperature.to_fahrenheit.round(0)
  end

  def current_feels_like
    @current.feels_like.to_fahrenheit.round(0)
  end

  def current_wind_speed
    @current.wind_speed.round(0)
  end

  def current_wind_direction
    case @current.wind_dir
    when 0..22.5
      "N"
    when 22.5..67.5
      "NE"
    when 67.5..112.5
      "E"
    when 112.5..157.5
      "SE"
    when 157.5..202.5
      "S"
    when 202.5..247.5
      "SW"
    when 247.5..292.5
      "W"
    when 292.5..337.5
      "NW"
    when 337.5..360
      "N"
    end
  end

  def current_humidity
    @current.humidity
  end

  def current_uvi
    @current.uvi.round
  end

  def current_solar_irradiance
    @current.uv.round
  end

  def current_uv_index_category
    uv_value = @current.uvi.to_i
    case uv_value
    when 0..2
      "Low"
    when 3..5
      "Moderate"
    when 6..7
      "High"
    when 8..10
      "Very High"
    else
      "Extreme"
    end
  end

  def current_sunrise
    @almanac.sunrise_at.in_time_zone("America/Los_Angeles").strftime("%I:%M %p")
  end

  def current_sunset
    @almanac.sunset_at.in_time_zone("America/Los_Angeles").strftime("%I:%M %p")
  end

  def current_rain_day
    @current.rain_day_in.round(2)
  end

  def current_rain_hour
    @current.rain_rate_in.round(2)
  end

  def current_dew_point
    @current.dew_point.to_fahrenheit.round(0)
  end

  def today_high
    @today_forecast&.temp_max&.round(0)
  end

  def today_low
    @today_forecast&.temp_min&.round(0)
  end

  def weather_icon
    @current_forecast&.weather_icon || "01d"
  end

  def weather_description
    @current_forecast&.weather_description&.titleize || "Clear"
  end

  def night_time?
    return false unless @current&.reading_date_time && @almanac

    !@current.reading_date_time.between?(@almanac.sunrise_at, @almanac.sunset_at)
  end
end
