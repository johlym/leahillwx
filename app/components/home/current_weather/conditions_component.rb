# frozen_string_literal: true

class Home::CurrentWeather::ConditionsComponent < ViewComponent::Base
  def initialize(current:, hourly:, almanac:)
    @current = current
    @hourly = hourly
    @almanac = almanac
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

  def current_humidity
    @current.humidity
  end

  def hourly_forecast
    @hourly
  end
end
