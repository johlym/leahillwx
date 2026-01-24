class RootController < ApplicationController
  def index
    @current = WeatherMeasurement
      .select("weather_measurements.*, (SELECT COUNT(*) FROM weather_measurements) as total_count")
      .order(reading_date_time: :desc)
      .first

    @almanac = AlmanacEntry.for_date(Date.today)

    forecast_record = Forecast.last

    # If no data exists at all, fetch synchronously
    if forecast_record.nil?
      ow_forecast = OpenWeatherApiService.new.retrieve_forecast
      forecast_record = Forecast.create(forecast: ow_forecast)
    # If data is stale, use it but refresh in background
    elsif forecast_record.created_at < 1.hour.ago
      DownloadOpenWeatherForecastJob.perform_async
    end

    @forecast = ForecastParserService.new(forecast_record).parse
    @earthquakes = Earthquake.last(5).reverse
  end

  def about
    @weather_measurement_count = WeatherMeasurement.count
    @first_weather_measurement = WeatherMeasurement.order(reading_date_time: :asc).first
  end
end
