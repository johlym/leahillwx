# frozen_string_literal: true

class UpdateCwopJob
  include Sidekiq::Job
  sidekiq_options retry: false

  def perform(measurement_id)
    return unless ENV["CWOP_CALLSIGN"].present? &&
                  ENV["LOCATION_LAT"].present? &&
                  ENV["LOCATION_LON"].present?

    measurement = WeatherMeasurement.find(measurement_id)
    UpdateThirdPartyWeatherPlatformService.new(measurement, "cwop").perform
  end
end
