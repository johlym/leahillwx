# frozen_string_literal: true

class UpdatePwsWeatherJob
  include Sidekiq::Job
  sidekiq_options retry: false

  def perform(measurement_id)
    return unless ENV["PWS_STATION_ID"].present? && ENV["PWS_STATION_KEY"].present?

    measurement = WeatherMeasurement.find(measurement_id)
    UpdateThirdPartyWeatherPlatformService.new(measurement, "pwsweather").perform
  end
end
