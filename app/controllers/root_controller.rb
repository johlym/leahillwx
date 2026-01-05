class RootController < ApplicationController
  def index
    @current = WeatherMeasurement.order(reading_date_time: :desc).first
  end
end
