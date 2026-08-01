# frozen_string_literal: true

class AlertsController < ApplicationController
  def index
    @weather_alerts = load_weather_alerts
  end

  # Async fragment for the site header alert bar. Loaded via Turbo Frame after
  # the page paints so LibreWXR never blocks the initial HTML response.
  def bar
    @weather_alerts = load_weather_alerts
    render layout: false
  end

  private

  def load_weather_alerts
    forecast_record = Forecast.latest
    forecast = ForecastParser.new(forecast_record || {}).parse
    lat, lon = LibreWxrAlertsClient.coordinates_from_env

    WeatherAlert.active_nearby(
      lat: lat,
      lon: lon,
      forecast_alerts: forecast&.alerts
    )
  end
end
