# frozen_string_literal: true

class AlertsController < ApplicationController
  def index
    forecast_record = Forecast.latest
    forecast = ForecastParser.new(forecast_record || {}).parse

    lat, lon = LibreWxrAlertsClient.coordinates_from_env
    @weather_alerts = WeatherAlert.active_nearby(
      lat: lat,
      lon: lon,
      forecast_alerts: forecast&.alerts
    )
  end
end
