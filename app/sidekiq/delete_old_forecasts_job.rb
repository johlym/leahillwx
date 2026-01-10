class DeleteOldForecastsJob
  include Sidekiq::Job

  def perform(*args)
    # Delete forecasts older than 7 days
    Forecast.where("created_at < ?", 7.days.ago).destroy_all
  end
end
