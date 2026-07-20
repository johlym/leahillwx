# frozen_string_literal: true

module ThirdPartyWeather
  class EnqueueUpdates
    PLATFORM_JOBS = [
      UpdateWeatherUndergroundJob,
      UpdatePwsWeatherJob,
      UpdateAwekasJob,
      UpdateWeathercloudJob,
      UpdateCwopJob
    ].freeze

    def self.call
      new.call
    end

    def call
      unless ENV["SEND_WX"] == "true"
        Rails.logger.debug "[third_party_weather] skipped: SEND_WX is not true"
        return
      end

      measurement = WeatherMeasurement.order(reading_date_time: :desc).first
      if measurement.nil?
        Rails.logger.info "[third_party_weather] skipped: no measurements available"
        return
      end

      PLATFORM_JOBS.each { |job_class| job_class.perform_async(measurement.id) }
      Rails.logger.info "[third_party_weather] enqueued #{PLATFORM_JOBS.size} uploads for measurement ##{measurement.id}"
    end
  end
end
