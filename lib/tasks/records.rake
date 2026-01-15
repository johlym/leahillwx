namespace :records do
  desc "Populate records for all available years and all-time"
  task populate: :environment do
    puts "Calculating all-time records..."
    RecordCalculator.new(scope: "all_time").calculate_and_save!
    puts "✓ All-time records calculated"

    years = WeatherMeasurement.distinct.pluck(Arel.sql("EXTRACT(YEAR FROM reading_date_time)")).map(&:to_i).sort

    years.each do |year|
      puts "Calculating records for year #{year}..."
      RecordCalculator.new(scope: "yearly", year: year).calculate_and_save!
      puts "✓ Year #{year} records calculated"
    end

    puts "\n✓ All records populated successfully!"
  end

  desc "Recalculate all records (deletes existing records first)"
  task recalculate: :environment do
    puts "Deleting existing records..."
    Record.delete_all
    puts "✓ Existing records deleted"

    Rake::Task["records:populate"].invoke
  end

  desc "Update records for a specific year"
  task :update_year, [ :year ] => :environment do |t, args|
    year = args[:year]&.to_i || Time.current.year

    puts "Calculating records for year #{year}..."
    RecordCalculator.new(scope: "yearly", year: year).calculate_and_save!
    puts "✓ Year #{year} records calculated"
  end

  desc "Update current year and all-time records (same as nightly job)"
  task update_current: :environment do
    current_year = Time.current.year

    puts "Calculating records for year #{current_year}..."
    RecordCalculator.new(scope: "yearly", year: current_year).calculate_and_save!
    puts "✓ Year #{current_year} records calculated"

    puts "Calculating all-time records..."
    RecordCalculator.new(scope: "all_time").calculate_and_save!
    puts "✓ All-time records calculated"

    puts "\n✓ Current records updated successfully!"
  end
end
