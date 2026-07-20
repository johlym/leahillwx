# frozen_string_literal: true

class UpdateWeatherUndergroundJob
  include Sidekiq::Job
  sidekiq_options retry: false

  def perform(measurement_id)
    ThirdPartyWeather::WeatherUnderground.call(measurement_id)
  end
end
