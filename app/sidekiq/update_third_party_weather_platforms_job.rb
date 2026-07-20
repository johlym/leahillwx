# frozen_string_literal: true

class UpdateThirdPartyWeatherPlatformsJob
  include Sidekiq::Job

  def perform(*_args)
    return if ENV["SEND_WX"] != "true"

    measurement = WeatherMeasurement.order(reading_date_time: :desc).first
    return if measurement.nil?

    measurement_id = measurement.id
    UpdateWeatherUndergroundJob.perform_async(measurement_id)
    UpdatePwsWeatherJob.perform_async(measurement_id)
    UpdateAwekasJob.perform_async(measurement_id)
    UpdateWeathercloudJob.perform_async(measurement_id)
    UpdateCwopJob.perform_async(measurement_id)
  end
end
