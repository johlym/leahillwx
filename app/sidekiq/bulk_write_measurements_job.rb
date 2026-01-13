class BulkWriteMeasurementsJob
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 3

  def perform(measurements)
    # measurements is an array of hashes (JSON-serializable)
    now = Time.current
    records = measurements.map do |m|
      m.merge("created_at" => now, "updated_at" => now)
    end

    # Use upsert_all to skip duplicates based on unique index
    WeatherMeasurement.upsert_all(records, unique_by: :reading_date_time)
  rescue ActiveRecord::RecordNotUnique => e
    # Log duplicate records but don't raise - continue processing
    Rails.logger.warn("Duplicate weather measurements detected: #{e.message}")
  rescue ActiveRecord::StatementInvalid => e
    # Log other database errors but don't raise
    Rails.logger.error("Database error in bulk measurement import: #{e.message}")
  end
end
