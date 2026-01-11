class UpdateThirdPartyWeatherPlatformsJob
  include Sidekiq::Job

  def perform(*args)
    wm = WeatherMeasurement.order(reading_date_time: :desc).first
    UpdateWeatherUndergroundJob.perform_async(wm)
    UpdatePwsWeatherJob.perform_async(wm)
    UpdateAwekasJob.perform_async(wm)
    UpdateWeathercloudJob.perform_async(wm)
    UpdateCwopJob.perform_async(wm)
  end
end
