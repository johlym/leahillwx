class Api::V1::WeatherMeasurementsController < ApiController
  before_action :authenticate, only: :create

  # @tags Weather Measurements
  # @summary Create a weather measurement
  # @request_body_ref #/components/requestBodies/createWeatherMeasurement
  # @security api_key
  # @response No Content(204) [nil]
  # @response Unprocessable Entity(422) [Hash{ errors: Array<String> }]
  # @response Unauthorized(401) [Hash{ error: String }]
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
