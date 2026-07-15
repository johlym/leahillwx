class DownloadOpenWeatherForecastJob
  include Sidekiq::Job

  def perform(*args)
    service = OpenWeatherClient.new

    ow_forecast = service.retrieve_forecast
    Forecast.create!(forecast: ow_forecast, interval: "daily")
  end
end
