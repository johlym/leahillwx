#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to fix report entries with incorrect UTC-based timestamps
# This will:
# 1. Delete all hourly entries (which have incorrect UTC times)
# 2. Regenerate hourly entries using Pacific time
# 3. Regenerate daily summaries to ensure they exist for all days with data

puts "=" * 80
puts "Report Entries Timezone Fix Script"
puts "=" * 80
puts

# Step 1: Get the date range of existing data
puts "Step 1: Analyzing existing data..."
first_measurement = WeatherMeasurement.order(:reading_date_time).first
last_measurement = WeatherMeasurement.order(:reading_date_time).last

if first_measurement.nil? || last_measurement.nil?
  puts "No weather measurements found. Nothing to fix."
  exit 0
end

start_date = first_measurement.reading_date_time.in_time_zone("America/Los_Angeles").to_date
end_date = last_measurement.reading_date_time.in_time_zone("America/Los_Angeles").to_date

puts "  First measurement: #{first_measurement.reading_date_time}"
puts "  Last measurement: #{last_measurement.reading_date_time}"
puts "  Date range (PST): #{start_date} to #{end_date}"
puts

# Step 2: Delete all hourly entries
puts "Step 2: Deleting incorrect hourly entries..."
hourly_count = ReportEntry.where.not(hour: nil).count
puts "  Found #{hourly_count} hourly entries to delete"
ReportEntry.where.not(hour: nil).delete_all
puts "  ✓ Deleted"
puts

# Step 3: Regenerate hourly entries
puts "Step 3: Regenerating hourly entries in Pacific time..."
start_time = start_date.in_time_zone("America/Los_Angeles").beginning_of_day
end_time = end_date.in_time_zone("America/Los_Angeles").end_of_day
total_hours = ((end_time - start_time) / 1.hour).to_i

puts "  Processing #{total_hours} hours..."

current_time = start_time
processed = 0
errors = 0

while current_time <= end_time
  if (processed % 100).zero?
    print "\r  Progress: #{processed}/#{total_hours} (#{(processed * 100.0 / total_hours).round(1)}%)"
  end

  begin
    GenerateHourlyReportJob.new.perform(current_time)
    processed += 1
  rescue StandardError => e
    errors += 1
    if errors <= 5 # Only show first 5 errors
      puts "\n  Error at #{current_time}: #{e.message}"
    end
  end

  current_time += 1.hour
end

puts "\r  Progress: #{processed}/#{total_hours} (100.0%)"
puts "  ✓ Generated #{processed} hourly entries"
puts "  ✗ Errors: #{errors}" if errors.positive?
puts

# Step 4: Regenerate daily summaries
puts "Step 4: Regenerating daily summaries..."
current_date = start_date
daily_processed = 0
daily_errors = 0

while current_date <= end_date
  print "\r  Processing #{current_date}..."

  begin
    GenerateReportJob.new.perform(current_date)
    daily_processed += 1
  rescue StandardError => e
    daily_errors += 1
    if daily_errors <= 5
      puts "\n  Error at #{current_date}: #{e.message}"
    end
  end

  current_date += 1.day
end

puts "\r  ✓ Generated #{daily_processed} daily summaries"
puts "  ✗ Errors: #{daily_errors}" if daily_errors.positive?
puts

# Step 5: Summary
puts "=" * 80
puts "Fix Complete!"
puts "=" * 80
puts "Summary:"
puts "  - Deleted: #{hourly_count} hourly entries"
puts "  - Created: #{processed} hourly entries"
puts "  - Updated: #{daily_processed} daily summaries"
if errors.positive? || daily_errors.positive?
  puts "  - Total errors: #{errors + daily_errors}"
  puts "    Check logs for details"
end
puts
