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
    measurement_params = permit_measurement_params(params.require(:weather_measurement))

    # Check if measurement with this timestamp already exists
    if WeatherMeasurement.exists?(reading_date_time: measurement_params[:reading_date_time])
      Rails.logger.info("Skipping duplicate measurement at #{measurement_params[:reading_date_time]}")
      head :no_content # Return success but don't insert
      return
    end

    @wm = WeatherMeasurement.new(measurement_params)
    if @wm.save
      head :no_content
    else
      render json: { errors: @wm.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # @tags Weather Measurements
  # @summary Bulk create weather measurements
  # @request_body [Hash{ weather_measurements: Array<Hash>, update_records: Boolean }] Array of weather measurement objects (max 1000)
  # @security api_key
  # @response Created(201) [Hash{ created: Integer, errors: Array }]
  # @response Unprocessable Entity(422) [Hash{ error: String }]
  # @response Unauthorized(401) [Hash{ error: String }]
  def bulk_create
    measurements_params = params.require(:weather_measurements)
    update_records = params[:update_records].to_s == "true"

    if measurements_params.length > MAX_BULK_RECORDS
      return render json: { error: "Maximum #{MAX_BULK_RECORDS} measurements allowed per request" }, status: :unprocessable_entity
    end

    # Convert to plain Hash array for Sidekiq strict_args (no HashWithIndifferentAccess)
    records = measurements_params.map do |measurement_data|
      # Use JSON round-trip to ensure plain Hash with string keys
      JSON.parse(permit_measurement_params(measurement_data).to_json)
    end

    # Enqueue background job
    BulkWriteMeasurementsJob.perform_async(records, update_records)

    render json: { accepted: records.size, status: "processing" }, status: :accepted
  end

  private

  def permit_measurement_params(data)
    data.permit(%i[reading_date_time barometer_abs barometer_rel gust_speed light humidity temperature rain_day rain_rate uv uvi wind_dir wind_speed heat_index dew_point wind_chill])
  end
end
