# frozen_string_literal: true

class UpdateAwekasJob
  include Sidekiq::Job
  sidekiq_options retry: false

  def perform(measurement_id)
    return unless ENV["AWEKAS_USERNAME"].present? && ENV["AWEKAS_PASSWORD"].present?

    measurement = WeatherMeasurement.find(measurement_id)
    UpdateThirdPartyWeatherPlatformService.new(measurement, "awekas").perform
  end
end
