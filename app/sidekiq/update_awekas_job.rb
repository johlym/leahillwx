# frozen_string_literal: true

class UpdateAwekasJob
  include Sidekiq::Job
  sidekiq_options retry: false

  def perform(measurement_id)
    ThirdPartyWeather::Awekas.call(measurement_id)
  end
end
