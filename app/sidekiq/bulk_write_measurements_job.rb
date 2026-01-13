class BulkWriteMeasurementsJob
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 3

  def perform(measurements)
    # measurements is an array of hashes (JSON-serializable)
    now = Time.current
    records = measurements.map do |m|
      m.merge("created_at" => now, "updated_at" => now)
    end

    # Check for existing records
    timestamps = records.map { |r| r["reading_date_time"] }
    existing_timestamps = WeatherMeasurement.where(reading_date_time: timestamps).pluck(:reading_date_time).to_set

    # Filter out duplicates
    new_records = records.reject do |record|
      if existing_timestamps.include?(record["reading_date_time"])
        Rails.logger.info("Skipping duplicate measurement at #{record['reading_date_time']}")
        true
      else
        false
      end
    end

    # Log duplicate count if any
    if new_records.size < records.size
      duplicates_count = records.size - new_records.size
      Rails.logger.info("Skipped #{duplicates_count} duplicate measurements in bulk import")
    end

    # Insert only new records
    WeatherMeasurement.insert_all!(new_records) if new_records.any?
  rescue => e
    Rails.logger.error("Error in bulk measurement import: #{e.message}")
  end
end
