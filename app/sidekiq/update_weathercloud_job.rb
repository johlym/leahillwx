# frozen_string_literal: true

class UpdateWeathercloudJob
  include Sidekiq::Job
  sidekiq_options retry: false

  def perform(measurement_id)
    return unless ENV["WEATHERCLOUD_DEVICE_ID"].present? && ENV["WEATHERCLOUD_DEVICE_KEY"].present?

    measurement = WeatherMeasurement.find(measurement_id)
    UpdateThirdPartyWeatherPlatformService.new(measurement, "weathercloud").perform
  end
end
