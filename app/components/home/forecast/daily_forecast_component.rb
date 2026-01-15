# frozen_string_literal: true

class Home::Forecast::DailyForecastComponent < ViewComponent::Base
  attr_reader :forecast

  def initialize(forecast:)
    @forecast = forecast
  end

  def formatted_timestamp
    forecast.created_at.in_time_zone("America/Los_Angeles").strftime("%B %-d, %Y @ %H:%S")
  end
end
