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
      # Validate first so a bad row cannot delete a good reading and then
      # get skipped. Ignore uniqueness — we are about to replace those rows.
      valid_records = validate_records!(records, ignore_timestamp_taken: true)
      timestamps = valid_records.filter_map { |r| parse_reading_time(r["reading_date_time"]) }
      deleted_count = 0

      WeatherMeasurement.transaction do
        deleted_count = WeatherMeasurement.where(reading_date_time: timestamps).delete_all if timestamps.any?
        WeatherMeasurement.insert_all!(valid_records) if valid_records.any?
      end

      WeatherMeasurements::TotalCount.recalculate! if deleted_count.positive? || valid_records.any?
      Rails.logger.info("Bulk import (overwrite): #{valid_records.size} inserted, #{deleted_count} deleted")
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
      insert_measurements!(new_records) if new_records.any?
      WeatherMeasurements::TotalCount.increment!(by: new_records.size)
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
      insert_measurements!(new_records) if new_records.any?
      WeatherMeasurements::TotalCount.increment!(by: new_records.size)
    end

  rescue => e
    Rails.logger.error("Error in bulk measurement import: #{e.message}")
    raise
  end

  private

  def insert_measurements!(records)
    valid_records = validate_records!(records)
    return if valid_records.empty?

    WeatherMeasurement.insert_all!(valid_records)
  end

  # insert_all! skips Active Record validations; mirror create-path checks first.
  def validate_records!(records, ignore_timestamp_taken: false)
    valid = []
    records.each do |attrs|
      measurement = WeatherMeasurement.new(attrs.except("created_at", "updated_at"))
      if acceptable_for_insert?(measurement, ignore_timestamp_taken: ignore_timestamp_taken)
        row = measurement.attributes.except("id")
        row["created_at"] = attrs["created_at"] || attrs[:created_at] || Time.current
        row["updated_at"] = attrs["updated_at"] || attrs[:updated_at] || Time.current
        valid << row
      else
        Rails.logger.warn(
          "Skipping invalid bulk measurement at #{attrs["reading_date_time"]}: #{measurement.errors.full_messages.join(", ")}"
        )
      end
    end
    valid
  end

  def acceptable_for_insert?(measurement, ignore_timestamp_taken:)
    return true if measurement.valid?
    return false unless ignore_timestamp_taken

    details = measurement.errors.details
    details.any? && details.all? do |attribute, errors|
      attribute == :reading_date_time && errors.all? { |error| error[:error] == :taken }
    end
  end

  def parse_reading_time(value)
    case value
    when Time, ActiveSupport::TimeWithZone then value
    when DateTime then value.in_time_zone
    else Time.zone.parse(value.to_s)
    end
  end
end
