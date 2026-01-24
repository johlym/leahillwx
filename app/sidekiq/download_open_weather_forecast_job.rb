class DownloadOpenWeatherForecastJob
  include Sidekiq::Job

  def perform(*args)
    service = OpenWeatherApiService.new

    ow_forecast = service.retrieve_forecast
    Forecast.create(forecast: ow_forecast)
  end
end
