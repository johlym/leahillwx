class RootController < ApplicationController
  def index
    @current = WeatherMeasurement.order(reading_date_time: :desc).first
    @forecast = ForecastParserService.new(Forecast.last).parse
  end

  def about
    @weather_measurement_count = WeatherMeasurement.count
  end
end
