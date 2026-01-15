# frozen_string_literal: true

class Home::Forecast::HourlyForecastComponent < ViewComponent::Base
  def initialize(forecast:)
    @forecast = forecast
  end
end
