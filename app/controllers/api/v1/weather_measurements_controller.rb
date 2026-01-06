class Api::V1::WeatherMeasurementsController < ApiController
  before_action :authenticate, only: [ :create, :bulk_create ]

  MAX_BULK_RECORDS = 1000

  # @tags Weather Measurements
  # @summary Create a weather measurement
  # @request_body_ref #/components/requestBodies/createWeatherMeasurement
  # @security api_key
  # @response No Content(204) [nil]
  # @response Unprocessable Entity(422) [Hash{ errors: Array<String> }]
  # @response Unauthorized(401) [Hash{ error: String }]
  def create
    @wm = WeatherMeasurement.new(permit_measurement_params(params.require(:weather_measurement)))
    if @wm.save
      head :no_content
    else
      render json: { errors: @wm.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # @tags Weather Measurements
  # @summary Bulk create weather measurements
  # @request_body [Hash{ weather_measurements: Array<Hash> }] Array of weather measurement objects (max 1000)
  # @security api_key
  # @response Created(201) [Hash{ created: Integer, errors: Array }]
  # @response Unprocessable Entity(422) [Hash{ error: String }]
  # @response Unauthorized(401) [Hash{ error: String }]
  def bulk_create
    measurements_params = params.require(:weather_measurements)

    if measurements_params.length > MAX_BULK_RECORDS
      return render json: { error: "Maximum #{MAX_BULK_RECORDS} measurements allowed per request" }, status: :unprocessable_entity
    end

    now = Time.current
    records = measurements_params.map do |measurement_data|
      permit_measurement_params(measurement_data).to_h.merge(created_at: now, updated_at: now)
    end

    begin
      WeatherMeasurement.insert_all!(records)
      render json: { created: records.size }, status: :created
    rescue ActiveRecord::RecordNotUnique => e
      render json: { error: "Duplicate record: #{e.message}" }, status: :unprocessable_entity
    rescue ActiveRecord::StatementInvalid => e
      render json: { error: "Insert failed: #{e.message}" }, status: :unprocessable_entity
    end
  end

  private

  def permit_measurement_params(data)
    data.permit(%i[reading_date_time barometer_abs barometer_rel day_max_wind gust_speed light humidity temperature rain_day rain_event rain_rate uv uvi wind_dir wind_speed])
  end
end
