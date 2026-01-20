# frozen_string_literal: true

class Home::CurrentWeather::ConditionsComponent < ViewComponent::Base
  def initialize(current:, almanac:)
    @current = current
    @almanac = almanac
  end

  def season
    @almanac.season_for_date(Date.today)
  end

  def current_temperature
    @current.temperature.to_fahrenheit.round(0)
  end

  def current_feels_like
    @current.feels_like.to_fahrenheit.round(0)
  end
end
