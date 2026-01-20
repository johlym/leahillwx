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
  task :generate_daily, [ :start_date, :end_date, :mode ] => :environment do |_t, args|
    generator = Almanac::EphemGenerator.new
    mode = args[:mode] || "incremental"  # Default to incremental

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
    puts "Mode:       #{mode}"
    puts "Start date: #{start_date}"
    puts "End date:   #{end_date}"
    puts "Total days: #{(end_date - start_date).to_i + 1}"
    puts "=" * 80
    puts

    if start_date > end_date
      puts "ERROR: Start date must be before or equal to end date"
      exit 1
    end

    # Determine which dates need processing
    dates_to_process = if mode == "incremental"
      # Find missing dates
      all_dates = (start_date..end_date).to_a
      existing_dates = AlmanacEntry.where(date: start_date..end_date).pluck(:date)
      missing_dates = all_dates - existing_dates

      # Analyze which fields are NULL in existing entries
      field_checks = {
        "sunrise_at" => "Sun rise/set times",
        "sunset_at" => "Sun rise/set times",
        "civil_dawn_at" => "Civil twilight times",
        "civil_dusk_at" => "Civil twilight times",
        "solar_noon_at" => "Solar noon",
        "moonrise_at" => "Moon rise/set times",
        "moonset_at" => "Moon rise/set times",
        "moon_transit_at" => "Moon transit",
        "moon_phase" => "Moon phase",
        "moon_illumination_pct" => "Moon illumination",
        "daylight_seconds" => "Daylight duration",
        "daylight_delta_seconds" => "Daylight delta",
        "sun_ecliptic_longitude_deg" => "Sun ecliptic longitude"
      }

      # Count NULL occurrences for each field
      null_counts = {}
      field_checks.keys.each do |field|
        count = AlmanacEntry.where(date: start_date..end_date)
          .where("#{field} IS NULL")
          .count
        null_counts[field] = count if count > 0
      end

      # Find entries with any NULL fields
      conditions = field_checks.keys.map { |f| "#{f} IS NULL" }.join(" OR ")
      incomplete_entries = AlmanacEntry.where(date: start_date..end_date)
        .where(conditions)
        .pluck(:date)

      dates_needing_update = (missing_dates + incomplete_entries).uniq.sort

      puts "Analysis:"
      puts "  Missing entries:    #{missing_dates.size}"
      puts "  Incomplete entries: #{incomplete_entries.size}"
      puts "  Total to process:   #{dates_needing_update.size}"
      puts

      if null_counts.any?
        puts "Missing fields in existing entries:"
        # Group by description to reduce noise
        grouped = null_counts.group_by { |field, _count| field_checks[field] }
        grouped.each do |description, fields|
          total = fields.map { |_f, count| count }.max
          puts "  - #{description}: #{total} entries"
        end
        puts
      end

      if dates_needing_update.empty?
        puts "✓ All entries are complete. Nothing to update."
        puts "  Use mode=full to force regeneration."
        exit 0
      end

      puts "Calculations to perform:"
      puts "  - Sun rise/set and twilight times"
      puts "  - Moon rise/set and phase"
      puts "  - Daylight duration and delta"
      puts "  - Sun ecliptic longitude (for seasons)"
      puts

      dates_needing_update
    else
      # Full mode: process all dates
      (start_date..end_date).to_a
    end

    processed = 0
    errors = 0
    batch_size = 1000
    entries = []
    total_days = dates_to_process.size
    current_day = 0

    dates_to_process.each do |date|
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
    puts "Skipped:   #{(end_date - start_date).to_i + 1 - total_days} days (already complete)" if mode == "incremental"
    puts "=" * 80
  end

  desc "Generate hourly position data from BSP ephemeris"
  task :generate_hourly, [ :start_date, :end_date, :mode ] => :environment do |_t, args|
    generator = Almanac::EphemGenerator.new
    mode = args[:mode] || "incremental"  # Default to incremental

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
    puts "Mode:        #{mode}"
    puts "Start date:  #{start_date}"
    puts "End date:    #{end_date}"
    puts "Total days:  #{(end_date - start_date).to_i + 1}"
    puts "Total hours: #{((end_date - start_date).to_i + 1) * 24}"
    puts "=" * 80
    puts

    if start_date > end_date
      puts "ERROR: Start date must be before or equal to end date"
      exit 1
    end

    # Determine which dates need processing
    dates_to_process = if mode == "incremental"
      # Find dates with missing hours (should have 24 positions per date)
      all_dates = (start_date..end_date).to_a

      # Get dates that have all 24 hours with no NULL fields
      complete_dates = AlmanacPosition
        .where(date: start_date..end_date)
        .where("sun_azimuth_deg IS NOT NULL AND sun_altitude_deg IS NOT NULL AND " \
               "sun_ra_deg IS NOT NULL AND sun_dec_deg IS NOT NULL AND " \
               "moon_azimuth_deg IS NOT NULL AND moon_altitude_deg IS NOT NULL AND " \
               "moon_ra_deg IS NOT NULL AND moon_dec_deg IS NOT NULL")
        .group(:date)
        .having("COUNT(*) = 24")
        .pluck(:date)
      dates_needing_update = all_dates - complete_dates

      # Analyze what's missing for incomplete dates
      if dates_needing_update.any?
        field_checks = [
          "sun_azimuth_deg", "sun_altitude_deg", "sun_ra_deg", "sun_dec_deg",
          "moon_azimuth_deg", "moon_altitude_deg", "moon_ra_deg", "moon_dec_deg"
        ]

        null_fields = {}
        field_checks.each do |field|
          count = AlmanacPosition.where(date: dates_needing_update)
            .where("#{field} IS NULL")
            .count
          null_fields[field] = count if count > 0
        end

        puts "Analysis:"
        puts "  Complete dates:     #{complete_dates.size}"
        puts "  Dates to process:   #{dates_needing_update.size}"
        puts

        if null_fields.any?
          puts "Issues found:"
          dates_with_partial = dates_needing_update.count { |d| AlmanacPosition.where(date: d).any? }
          dates_with_none = dates_needing_update.count { |d| AlmanacPosition.where(date: d).none? }

          puts "  - #{dates_with_none} dates with no hourly data" if dates_with_none > 0
          puts "  - #{dates_with_partial} dates with partial data" if dates_with_partial > 0

          if null_fields.any?
            puts "  Missing position fields:"
            null_fields.each do |field, count|
              field_name = field.gsub("_deg", "").gsub("_", " ").capitalize
              puts "    · #{field_name}: #{count} records"
            end
          end
          puts
        end

        puts "Calculations to perform:"
        puts "  - BSP ephemeris lookups for Sun and Moon positions"
        puts "  - Equatorial to horizontal coordinate conversions"
        puts "  - 24 hourly positions per date"
        puts
      else
        puts "Analysis:"
        puts "  Complete dates:     #{complete_dates.size}"
        puts "  Dates to process:   0"
        puts
      end

      if dates_needing_update.empty?
        puts "✓ All hourly positions are complete. Nothing to update."
        puts "  Use mode=full to force regeneration."
        exit 0
      end

      dates_needing_update
    else
      # Full mode: process all dates
      (start_date..end_date).to_a
    end

    processed = 0
    errors = 0
    batch_size = 500
    positions = []
    total_days = dates_to_process.size
    current_day = 0

    dates_to_process.each do |date|
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
    puts "Skipped:   #{((end_date - start_date).to_i + 1 - total_days) * 24} hours (already complete)" if mode == "incremental"
    puts "=" * 80
  end

  desc "Generate all almanac data (daily entries + hourly positions)"
  task :generate_all, [ :start_date, :end_date, :mode ] => :environment do |_t, args|
    mode = args[:mode] || "incremental"  # Default to incremental

    puts "=" * 80
    puts "Generating Complete Almanac Dataset"
    puts "=" * 80
    puts "Mode: #{mode}"
    puts "=" * 80
    puts

    # Invoke both tasks with the same date range and mode
    if args[:start_date] && args[:end_date]
      Rake::Task["almanac:generate_daily"].invoke(args[:start_date], args[:end_date], mode)
      Rake::Task["almanac:generate_hourly"].invoke(args[:start_date], args[:end_date], mode)
    else
      Rake::Task["almanac:generate_daily"].invoke(nil, nil, mode)
      Rake::Task["almanac:generate_hourly"].invoke(nil, nil, mode)
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
