class RootController < ApplicationController
  def index
    @current = WeatherMeasurement
      .select("weather_measurements.*, (SELECT COUNT(*) FROM weather_measurements) as total_count")
      .order(reading_date_time: :desc)
      .first

    forecast_record = Forecast.last
    if forecast_record.nil?
      ow_forecast = OpenWeatherApiService.new.retrieve_forecast
      forecast_record = Forecast.create(forecast: ow_forecast)
    end

    @forecast = ForecastParserService.new(forecast_record).parse
  end

  def about
    @weather_measurement_count = WeatherMeasurement.count
    @first_weather_measurement = WeatherMeasurement.order(reading_date_time: :asc).first
  end
end
