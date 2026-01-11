class UpdateThirdPartyWeatherPlatformsJob
  include Sidekiq::Job

  def perform(*args)
    wm = WeatherMeasurement.order(reading_date_time: :desc).first
    UpdateWeatherUndergroundJob.perform_later(wm)
    UpdatePwsWeatherJob.perform_later(wm)
    UpdateAwekasJob.perform_later(wm)
    UpdateWeathercloudJob.perform_later(wm)
    UpdateCwopJob.perform_later(wm)
  end
end
