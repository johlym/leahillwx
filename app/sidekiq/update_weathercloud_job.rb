# frozen_string_literal: true

class UpdateWeathercloudJob
  include Sidekiq::Job
  sidekiq_options retry: false

  def perform(measurement_id)
    ThirdPartyWeather::Weathercloud.call(measurement_id)
  end
end
