# frozen_string_literal: true

class UpdateWeatherUndergroundJob
  include Sidekiq::Job
  sidekiq_options retry: false

  def perform(measurement_id)
    return unless ENV["WU_STATION_ID"].present? && ENV["WU_STATION_KEY"].present?

    measurement = WeatherMeasurement.find(measurement_id)
    UpdateThirdPartyWeatherPlatformService.new(measurement, "weatherunderground").perform
  end
end
