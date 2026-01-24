class UpdateThirdPartyWeatherPlatformsJob
  include Sidekiq::Job

  def perform(*args)
    return if ENV["SEND_WX"] != "true"
    wm = WeatherMeasurement.order(reading_date_time: :desc).first.id
    UpdateWeatherUndergroundJob.perform_async(wm)
    UpdatePwsWeatherJob.perform_async(wm)
    UpdateAwekasJob.perform_async(wm)
    UpdateWeathercloudJob.perform_async(wm)
    UpdateCwopJob.perform_async(wm)
  end
end
