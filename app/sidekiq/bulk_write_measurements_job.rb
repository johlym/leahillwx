class BulkWriteMeasurementsJob
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 3

  def perform(measurements, update_records = false, overwrite = false)
    # measurements is an array of hashes (JSON-serializable)
    now = Time.current
    records = measurements.map do |m|
      m.merge("created_at" => now, "updated_at" => now)
    end

    # Check for existing records - parse string timestamps to DateTime for comparison
    timestamps = records.map { |r| Time.zone.parse(r["reading_date_time"]) }
    existing_records = WeatherMeasurement.where(reading_date_time: timestamps)
                                         .index_by(&:reading_date_time)

    if overwrite
      # Overwrite mode: delete existing and insert all records
      timestamps = records.map { |r| Time.zone.parse(r["reading_date_time"]) }
      deleted_count = WeatherMeasurement.where(reading_date_time: timestamps).delete_all

      # Insert all records
      WeatherMeasurement.insert_all!(records) if records.any?
      Rails.logger.info("Bulk import (overwrite): #{records.size} inserted, #{deleted_count} deleted")
    elsif update_records
      # Update existing records and insert new ones
      new_records = []
      updated_count = 0

      records.each do |record|
        record_time = Time.zone.parse(record["reading_date_time"])
        if existing = existing_records[record_time]
          # Update existing record
          existing.update!(record.except("created_at"))
          updated_count += 1
        else
          # New record to insert
          new_records << record
        end
      end

      # Insert new records in bulk
      WeatherMeasurement.insert_all!(new_records) if new_records.any?
      Rails.logger.info("Bulk import: #{new_records.size} created, #{updated_count} updated")
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
    raise
  end
end
