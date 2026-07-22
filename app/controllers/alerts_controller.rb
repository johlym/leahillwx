# frozen_string_literal: true

class AlertsController < ApplicationController
  def index
    forecast_record = Forecast.latest
    forecast = ForecastParser.new(forecast_record || {}).parse

    @weather_alerts = WeatherAlert.active_nearby(
      lat: ENV["LOCATION_LAT"]&.to_f,
      lon: ENV["LOCATION_LON"]&.to_f,
      forecast_alerts: forecast&.alerts
    )
  end
end
