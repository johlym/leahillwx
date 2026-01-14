class BulkWriteMeasurementsJob
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 3

  def perform(measurements, update_records = false)
    # measurements is an array of hashes (JSON-serializable)
    now = Time.current
    records = measurements.map do |m|
      m.merge("created_at" => now, "updated_at" => now)
    end

    # Check for existing records - parse string timestamps to DateTime for comparison
    timestamps = records.map { |r| Time.zone.parse(r["reading_date_time"]) }
    existing_records = WeatherMeasurement.where(reading_date_time: timestamps)
                                         .index_by(&:reading_date_time)

    if update_records
      # Update existing records and insert new ones
      records_to_insert = []
      records_to_update = []

      records.each do |record|
        record_time = Time.zone.parse(record["reading_date_time"])
        if existing_records[record_time]
          records_to_update << record
        else
          records_to_insert << record
        end
      end

      # Use upsert_all to handle both inserts and updates
      WeatherMeasurement.upsert_all(
        records,
        unique_by: :reading_date_time,
        update_only: records.first.keys - [ "reading_date_time", "created_at" ]
      ) if records.any?

      Rails.logger.info("Bulk import: #{records_to_insert.size} created, #{records_to_update.size} updated")
    else
      # Original behavior: filter out duplicates
      existing_timestamps = existing_records.keys.to_set

      new_records = records.reject do |record|
        record_time = Time.zone.parse(record["reading_date_time"])
        if existing_timestamps.include?(record_time)
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
    end
  rescue => e
    Rails.logger.error("Error in bulk measurement import: #{e.message}")
  end
end
