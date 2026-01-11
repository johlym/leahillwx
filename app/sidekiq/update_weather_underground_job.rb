class UpdateWeatherUndergroundJob
  include Sidekiq::Job
  sidekiq_options retry: false

  def perform(*args)
    nil unless ENV["WU_STATION_ID"] && ENV["WU_STATION_KEY"]
    # Do something
  end
end
