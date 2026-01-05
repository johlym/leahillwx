class RootController < ApplicationController
  def index
    @current = WeatherMeasurement.last
  end
end
