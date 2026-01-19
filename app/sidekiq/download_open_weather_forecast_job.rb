class DownloadOpenWeatherForecastJob
  include Sidekiq::Job

  def perform(*args)
    service = OpenWeatherApiService.new

    ow_forecast = service.retrieve_forecast
    forecast = Forecast.new(forecast: ow_forecast)
    forecast.save

    ow_current = service.retrieve_current
    current_forecast = Forecast.new(forecast: ow_current, interval: "current")
    current_forecast.save
  end
end
