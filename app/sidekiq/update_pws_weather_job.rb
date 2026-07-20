# frozen_string_literal: true

class UpdatePwsWeatherJob
  include Sidekiq::Job
  sidekiq_options retry: false

  def perform(measurement_id)
    ThirdPartyWeather::PwsWeather.call(measurement_id)
  end
end
