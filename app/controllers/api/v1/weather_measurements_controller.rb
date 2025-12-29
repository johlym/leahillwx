class Api::V1::WeatherMeasurementsController < ApiController
  before_action :authenticate, only: :create

  # @tags Weather Measurements
  # @summary Create a weather measurement
  # @description Records a new weather measurement from a weather station. All fields are required.
  # @request_body The weather measurement data [Hash{ weather_measurement: Hash{ reading_date_time: DateTime, barometer_abs: Float, barometer_rel: Float, day_max_wind: Float, gust_speed: Float, humidity: Integer, light: Float, rain_day: Float, rain_event: Float, rain_rate: Float, temperature: Float, uv: Integer, uvi: Float, wind_dir: Integer, wind_speed: Float } }]
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
