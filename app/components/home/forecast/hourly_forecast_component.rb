# frozen_string_literal: true

class Home::Forecast::HourlyForecastComponent < ViewComponent::Base
  attr_reader :forecast, :almanac

  def initialize(forecast:, almanac:)
    @forecast = forecast
    @almanac = almanac
  end

  def formatted_timestamp
    forecast.created_at.in_time_zone("America/Los_Angeles").strftime("%B %-d, %Y @ %H:%S")
  end
end
