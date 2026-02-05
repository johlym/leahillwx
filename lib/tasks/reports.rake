namespace :reports do
  desc "Backfill historical reports from weather data"
  task :backfill, [ :start_date, :end_date ] => :environment do |_t, args|
    start_date = args[:start_date] ? Date.parse(args[:start_date]) : Date.parse("2021-12-01")
    end_date = args[:end_date] ? Date.parse(args[:end_date]) : Date.yesterday

    puts "=" * 80
    puts "Backfilling Weather Reports"
    puts "=" * 80
    puts "Start date: #{start_date}"
    puts "End date:   #{end_date}"
    puts "Total days: #{(end_date - start_date).to_i + 1}"
    puts "=" * 80
    puts

    if start_date > end_date
      puts "ERROR: Start date must be before or equal to end date"
      exit 1
    end

    processed = 0
    errors = 0

    (start_date..end_date).each do |date|
      print "Processing #{date}... "

      begin
        aggregator = WeatherData::DailyAggregator.new(date)
        entry = aggregator.aggregate

        status = entry.partial_period ? "✓ (partial)" : "✓"
        puts status
        processed += 1
      rescue StandardError => e
        puts "✗ ERROR: #{e.message}"
        errors += 1
      end
    end

    puts
    puts "=" * 80
    puts "Backfill Complete"
    puts "=" * 80
    puts "Processed: #{processed} days"
    puts "Errors:    #{errors} days"
    puts "=" * 80
  end

  desc "Backfill hourly reports for a specific day or date range"
  task :backfill_hourly, [ :start_date, :end_date ] => :environment do |_t, args|
    start_date = args[:start_date] ? Date.parse(args[:start_date]) : Date.parse("2021-12-01")
    end_date = args[:end_date] ? Date.parse(args[:end_date]) : Date.yesterday

    puts "=" * 80
    puts "Backfilling Hourly Weather Reports"
    puts "=" * 80
    puts "Start date: #{start_date}"
    puts "End date:   #{end_date}"
    puts "Total days: #{(end_date - start_date).to_i + 1}"
    puts "Total hours: #{((end_date - start_date).to_i + 1) * 24}"
    puts "=" * 80
    puts

    if start_date > end_date
      puts "ERROR: Start date must be before or equal to end date"
      exit 1
    end

    processed = 0
    errors = 0
    total_hours = ((end_date - start_date).to_i + 1) * 24

    (start_date..end_date).each do |date|
      puts "\nProcessing #{date}..."
      (0..23).each do |hour|
        datetime = Time.zone.parse("#{date} #{hour}:00:00")
        print "  Hour #{hour.to_s.rjust(2, '0')}:00... "

        begin
          aggregator = WeatherData::HourlyAggregator.new(datetime)
          entry = aggregator.aggregate

          status = entry.partial_period ? "✓ (partial)" : "✓"
          puts status
          processed += 1
        rescue StandardError => e
          puts "✗ ERROR: #{e.message}"
          errors += 1
        end
      end
    end

    puts
    puts "=" * 80
    puts "Hourly Backfill Complete"
    puts "=" * 80
    puts "Processed: #{processed}/#{total_hours} hours"
    puts "Errors:    #{errors} hours"
    puts "=" * 80
  end

  desc "Purge and regenerate a specific report"
  task :purge, [ :year, :month ] => :environment do |_t, args|
    unless args[:year] && args[:month]
      puts "ERROR: Both year and month are required"
      puts "Usage: rake reports:purge[2024,1]"
      exit 1
    end

    year = args[:year].to_i
    month = args[:month].to_i

    unless (1..12).include?(month)
      puts "ERROR: Month must be between 1 and 12"
      exit 1
    end

    report = Report.find_by(year: year, month: month)
    month_name = Date::MONTHNAMES[month]

    puts "=" * 80
    puts "Purging Report: #{month_name} #{year}"
    puts "=" * 80

    if report
      entry_count = report.entries.count
      puts "Found existing report with #{entry_count} entries"
      puts "Deleting report and all entries..."
      report.destroy
      puts "✓ Report deleted"
    else
      puts "No existing report found for #{month_name} #{year}"
    end

    puts
    puts "Regenerating report..."
    puts

    # Get all days in the month
    start_date = Date.new(year, month, 1)
    end_date = Date.new(year, month, -1)

    processed = 0
    errors = 0

    (start_date..end_date).each do |date|
      print "Processing day #{date.day}... "

      begin
        aggregator = WeatherData::DailyAggregator.new(date)
        entry = aggregator.aggregate

        status = entry.partial_period ? "✓ (partial)" : "✓"
        puts status
        processed += 1
      rescue StandardError => e
        puts "✗ ERROR: #{e.message}"
        errors += 1
      end
    end

    puts
    puts "=" * 80
    puts "Regeneration Complete"
    puts "=" * 80
    puts "Processed: #{processed} days"
    puts "Errors:    #{errors} days"
    puts "=" * 80
  end

  desc "Purge all reports (requires confirmation)"
  task purge_all: :environment do
    total_reports = Report.count

    puts "=" * 80
    puts "⚠️  WARNING: DELETE ALL REPORTS"
    puts "=" * 80
    puts "This will permanently delete:"
    puts "  - #{total_reports} reports"
    puts "  - #{ReportEntry.count} report entries"
    puts
    puts "This action CANNOT be undone!"
    puts "=" * 80
    puts

    if total_reports.zero?
      puts "No reports found. Nothing to delete."
      exit 0
    end

    print "Type 'DELETE ALL REPORTS' to confirm: "
    confirmation = $stdin.gets.chomp

    if confirmation == "DELETE ALL REPORTS"
      puts
      puts "Deleting all reports..."

      Report.destroy_all

      puts "✓ All reports deleted"
      puts
      puts "To regenerate reports, run:"
      puts "  rake reports:backfill"
    else
      puts
      puts "Deletion cancelled."
    end
  end

  desc "Regenerate all reports (purge and backfill in one command)"
  task :regenerate_all, [ :start_date, :end_date ] => :environment do |_t, args|
    start_date = args[:start_date] ? Date.parse(args[:start_date]) : Date.parse("2021-12-01")
    end_date = args[:end_date] ? Date.parse(args[:end_date]) : Date.yesterday

    total_reports = Report.count
    total_entries = ReportEntry.count

    puts "=" * 80
    puts "Regenerating All Weather Reports"
    puts "=" * 80
    puts "This will delete #{total_reports} reports and #{total_entries} entries"
    puts "Then regenerate from #{start_date} to #{end_date}"
    puts "Total days: #{(end_date - start_date).to_i + 1}"
    puts "=" * 80
    puts

    # Purge existing reports
    if total_reports > 0
      puts "Deleting existing reports..."
      Report.destroy_all
      puts "✓ All reports deleted"
      puts
    end

    # Backfill
    if start_date > end_date
      puts "ERROR: Start date must be before or equal to end date"
      exit 1
    end

    daily_processed = 0
    daily_errors = 0
    hourly_processed = 0
    hourly_errors = 0

    # Process daily aggregations
    puts "Processing daily aggregations..."
    puts
    (start_date..end_date).each do |date|
      print "Processing #{date}... "

      begin
        aggregator = WeatherData::DailyAggregator.new(date)
        entry = aggregator.aggregate

        status = entry.partial_period ? "✓ (partial)" : "✓"
        puts status
        daily_processed += 1
      rescue StandardError => e
        puts "✗ ERROR: #{e.message}"
        daily_errors += 1
      end
    end

    puts
    puts "Daily aggregations complete. Processing hourly aggregations..."
    puts

    # Process hourly aggregations
    total_hours = ((end_date - start_date).to_i + 1) * 24
    (start_date..end_date).each do |date|
      puts "\nProcessing #{date}..."
      (0..23).each do |hour|
        datetime = Time.zone.parse("#{date} #{hour}:00:00")
        print "  Hour #{hour.to_s.rjust(2, '0')}:00... "

        begin
          aggregator = WeatherData::HourlyAggregator.new(datetime)
          entry = aggregator.aggregate

          status = entry.partial_period ? "✓ (partial)" : "✓"
          puts status
          hourly_processed += 1
        rescue StandardError => e
          puts "✗ ERROR: #{e.message}"
          hourly_errors += 1
        end
      end
    end

    puts
    puts "=" * 80
    puts "Regeneration Complete"
    puts "=" * 80
    puts "Daily Reports:"
    puts "  Processed: #{daily_processed} days"
    puts "  Errors:    #{daily_errors} days"
    puts
    puts "Hourly Reports:"
    puts "  Processed: #{hourly_processed}/#{total_hours} hours"
    puts "  Errors:    #{hourly_errors} hours"
    puts "=" * 80
  end
end
