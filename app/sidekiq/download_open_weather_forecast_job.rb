# frozen_string_literal: true

class DownloadOpenWeatherForecastJob
  include Sidekiq::Job

  def perform(*_args)
    service = OpenWeatherClient.new

    ow_forecast = service.retrieve_forecast
    Forecast.create!(forecast: ow_forecast, interval: "daily")
  rescue OpenWeatherClient::RequestError => e
    Rails.logger.warn("OpenWeather forecast download failed: #{e.message}")
  end
end
