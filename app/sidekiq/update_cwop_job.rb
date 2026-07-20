# frozen_string_literal: true

class UpdateCwopJob
  include Sidekiq::Job
  sidekiq_options retry: false

  def perform(measurement_id)
    ThirdPartyWeather::Cwop.call(measurement_id)
  end
end
