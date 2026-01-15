class RootController < ApplicationController
  def index
    @current = WeatherMeasurement
      .select("weather_measurements.*, (SELECT COUNT(*) FROM weather_measurements) as total_count")
      .order(reading_date_time: :desc)
      .first

    forecast_record = Forecast.where(interval: "daily").last
    if forecast_record.nil?
      ow_forecast = OpenWeatherApiService.new.retrieve_forecast
      forecast_record = Forecast.create(forecast: ow_forecast, interval: "daily")
    end

    hourly_forecast_record = Forecast.where(interval: "hourly").last
    if hourly_forecast_record.nil?
      ow_hourly_forecast = OpenWeatherApiService.new.retrieve_forecast
      hourly_forecast_record = Forecast.create(forecast: ow_hourly_forecast, interval: "hourly")
    end

    @forecast = ForecastParserService.new(forecast_record).parse
    @hourly_forecast = ForecastParserService.new(hourly_forecast_record).parse
    @earthquakes = Earthquake.last(5).reverse
  end

  def about
    @weather_measurement_count = WeatherMeasurement.count
    @first_weather_measurement = WeatherMeasurement.order(reading_date_time: :asc).first
  end
end
