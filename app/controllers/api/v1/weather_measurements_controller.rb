class Api::V1::WeatherMeasurementsController < ApiController
  before_action :authenticate, only: :create

  def create
    @wm = WeatherMeasurement.new(weather_measurement_params)
    if @wm.save
      head :no_content
    else
      render json: { errors: @wm.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def weather_measurement_params
    params.require(:weather_measurement).permit(:reading_date_time, :barometer_abs, :barometer_rel, :day_max_wind, :gust_speed, :light, :humidity, :temperature, :rain_day, :rain_event, :rain_rate, :uv, :uvi, :wind_dir, :wind_speed)
  end
end
