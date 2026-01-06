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

    results = { created: 0, errors: [] }

    ActiveRecord::Base.transaction do
      measurements_params.each_with_index do |measurement_data, index|
        wm = WeatherMeasurement.new(permit_measurement_params(measurement_data))
        if wm.save
          results[:created] += 1
        else
          results[:errors] << { index: index, errors: wm.errors.full_messages }
        end
      end

      if results[:errors].any?
        raise ActiveRecord::Rollback
      end
    end

    if results[:errors].any?
      render json: results, status: :unprocessable_entity
    else
      render json: results, status: :created
    end
  end

  private

  def permit_measurement_params(data)
    data.permit(%i[reading_date_time barometer_abs barometer_rel day_max_wind gust_speed light humidity temperature rain_day rain_event rain_rate uv uvi wind_dir wind_speed])
  end
end
