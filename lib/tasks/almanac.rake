namespace :almanac do
  desc "Debug: Inspect BSP file segments and coverage"
  task debug_bsp: :environment do
    puts "=" * 80
    puts "BSP File Inspection"
    puts "=" * 80

    bsp_path = Rails.root.join("vendor", "de440s.bsp")
    spk = Ephem::SPK.open(bsp_path.to_s)

    puts "\nAvailable segments:"
    puts "-" * 80

    # Try to list all segments and their methods
    spk.segments.each_with_index do |segment, idx|
      puts "\nSegment #{idx + 1}:"
      puts "  Center: #{segment.center}"
      puts "  Target: #{segment.target}"
      puts "  Class: #{segment.class}"
      puts "  Methods: #{segment.methods.grep(/time|date|jd|epoch|start|end|begin|coverage/).sort.join(', ')}"

      # Try to get coverage info
      begin
        if segment.respond_to?(:coverage)
          coverage = segment.coverage
          puts "  Coverage: #{coverage.inspect}"
        end
        if segment.respond_to?(:start_time)
          puts "  Start: #{segment.start_time}"
        end
        if segment.respond_to?(:end_time)
          puts "  End: #{segment.end_time}"
        end
      rescue => e
        puts "  Error getting coverage: #{e.message}"
      end
    end

    puts "\n" + "=" * 80
  end

  desc "Generate daily almanac entries from BSP ephemeris data"
  task :generate_daily, [ :start_date, :end_date ] => :environment do |_t, args|
    generator = Almanac::EphemGenerator.new

    # Determine date range
    if args[:start_date] && args[:end_date]
      start_date = Date.parse(args[:start_date])
      end_date = Date.parse(args[:end_date])
    else
      # Query actual BSP file coverage
      coverage = generator.bsp_coverage
      start_date = coverage[:start_date]
      end_date = coverage[:end_date]

      puts "Auto-detected BSP coverage:"
      puts "  Start: #{start_date}"
      puts "  End:   #{end_date}"
      puts
    end

    puts "=" * 80
    puts "Generating Daily Almanac Entries"
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
    batch_size = 1000
    entries = []
    total_days = (end_date - start_date).to_i + 1
    current_day = 0

    (start_date..end_date).each do |date|
      current_day += 1
      begin
        entry_data = generator.generate_daily_entry(date)
        entries << entry_data

        # Batch insert every 1000 entries
        if entries.size >= batch_size
          AlmanacEntry.upsert_all(entries, unique_by: :date)
          processed += entries.size
          entries = []
        end

        # Update progress on every iteration
        percentage = (current_day.to_f / total_days * 100).round(1)
        print "\rProgress: #{current_day}/#{total_days} - #{percentage}%"
      rescue StandardError => e
        puts "\n✗ ERROR on #{date}: #{e.message}"
        errors += 1
      end
    end

    # Insert remaining entries
    if entries.any?
      AlmanacEntry.upsert_all(entries, unique_by: :date)
      processed += entries.size
    end

    puts
    puts
    puts "=" * 80
    puts "Daily Generation Complete"
    puts "=" * 80
    puts "Processed: #{processed} days"
    puts "Errors:    #{errors} days"
    puts "=" * 80
  end

  desc "Generate hourly position data from BSP ephemeris"
  task :generate_hourly, [ :start_date, :end_date ] => :environment do |_t, args|
    generator = Almanac::EphemGenerator.new

    # Determine date range
    if args[:start_date] && args[:end_date]
      start_date = Date.parse(args[:start_date])
      end_date = Date.parse(args[:end_date])
    else
      # Query actual BSP file coverage
      coverage = generator.bsp_coverage
      start_date = coverage[:start_date]
      end_date = coverage[:end_date]

      puts "Auto-detected BSP coverage:"
      puts "  Start: #{start_date}"
      puts "  End:   #{end_date}"
      puts
    end

    puts "=" * 80
    puts "Generating Hourly Almanac Positions"
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
    batch_size = 500
    positions = []
    total_days = (end_date - start_date).to_i + 1
    current_day = 0

    (start_date..end_date).each do |date|
      current_day += 1
      begin
        hourly_positions = generator.generate_hourly_positions(date)
        positions.concat(hourly_positions)

        # Batch insert every 500 days (12,000 rows)
        if positions.size >= batch_size * 24
          AlmanacPosition.upsert_all(positions, unique_by: [ :date, :hour ])
          processed += positions.size
          positions = []
        end

        # Update progress on every iteration
        percentage = (current_day.to_f / total_days * 100).round(1)
        print "\rProgress: #{current_day}/#{total_days} - #{percentage}%"
      rescue StandardError => e
        puts "\n✗ ERROR on #{date}: #{e.message}"
        errors += 1
      end
    end

    # Insert remaining positions
    if positions.any?
      AlmanacPosition.upsert_all(positions, unique_by: [ :date, :hour ])
      processed += positions.size
    end

    puts
    puts
    puts "=" * 80
    puts "Hourly Generation Complete"
    puts "=" * 80
    puts "Processed: #{processed} hours"
    puts "Errors:    #{errors} hours"
    puts "=" * 80
  end

  desc "Generate all almanac data (daily entries + hourly positions)"
  task :generate_all, [ :start_date, :end_date ] => :environment do |_t, args|
    puts "=" * 80
    puts "Generating Complete Almanac Dataset"
    puts "=" * 80
    puts

    # Invoke both tasks with the same date range
    if args[:start_date] && args[:end_date]
      Rake::Task["almanac:generate_daily"].invoke(args[:start_date], args[:end_date])
      Rake::Task["almanac:generate_hourly"].invoke(args[:start_date], args[:end_date])
    else
      Rake::Task["almanac:generate_daily"].invoke
      Rake::Task["almanac:generate_hourly"].invoke
    end

    puts
    puts "=" * 80
    puts "Complete Almanac Generation Finished"
    puts "=" * 80
  end

  desc "Purge all almanac data (requires confirmation)"
  task purge_all: :environment do
    total_entries = AlmanacEntry.count
    total_positions = AlmanacPosition.count

    puts "=" * 80
    puts "⚠️  WARNING: DELETE ALL ALMANAC DATA"
    puts "=" * 80
    puts "This will permanently delete:"
    puts "  - #{total_entries} almanac entries"
    puts "  - #{total_positions} almanac positions"
    puts
    puts "This action CANNOT be undone!"
    puts "=" * 80
    puts

    if total_entries.zero? && total_positions.zero?
      puts "No almanac data found. Nothing to delete."
      exit 0
    end

    print "Type 'DELETE ALL ALMANAC DATA' to confirm: "
    confirmation = $stdin.gets.chomp

    if confirmation == "DELETE ALL ALMANAC DATA"
      puts
      puts "Deleting all almanac data..."

      AlmanacEntry.delete_all
      AlmanacPosition.delete_all

      puts "✓ All almanac data deleted"
      puts
      puts "To regenerate almanac data, run:"
      puts "  rake almanac:generate_all"
    else
      puts
      puts "Deletion cancelled."
    end
  end
end
