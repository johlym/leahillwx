# frozen_string_literal: true

class UpdateThirdPartyWeatherPlatformsJob
  include Sidekiq::Job

  def perform(*_args)
    ThirdPartyWeather::EnqueueUpdates.call
  end
end
