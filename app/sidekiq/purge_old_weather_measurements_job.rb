class PurgeOldWeatherMeasurementsJob
  include Sidekiq::Job

  BATCH_SIZE = 1_000
  DEFAULT_RETENTION_DAYS = 1_095

  def perform(*_args)
    cutoff = retention_days.days.ago
    deleted = 0

    loop do
      ids = WeatherMeasurement.where("reading_date_time < ?", cutoff).limit(BATCH_SIZE).pluck(:id)
      break if ids.empty?

      deleted += WeatherMeasurement.where(id: ids).delete_all
    end

    WeatherMeasurements::TotalCount.recalculate! if deleted.positive?
    deleted
  end

  def self.retention_days
    Integer(ENV.fetch("MEASUREMENT_RETENTION_DAYS", DEFAULT_RETENTION_DAYS.to_s))
  end

  private

  def retention_days
    self.class.retention_days
  end
end
