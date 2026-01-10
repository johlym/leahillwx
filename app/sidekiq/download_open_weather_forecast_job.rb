class DownloadOpenWeatherForecastJob
  include Sidekiq::Job

  def perform(*args)
    ow_forecast = OpenWeatherApiService.new.retrieve_forecast
    forecast = Forecast.new(forecast: ow_forecast)
    forecast.save
  end
end
