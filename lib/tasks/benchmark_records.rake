namespace :records do
  desc "Benchmark record calculation performance"
  task benchmark: :environment do
    require "benchmark"

    puts "\n=== Record Calculation Benchmark ==="
    puts "Testing with current year (#{Time.current.year})"
    puts "=" * 50

    result = Benchmark.measure do
      RecordCalculator.new(scope: "yearly", year: Time.current.year).calculate_and_save!
    end

    puts "\nCurrent Year Calculation:"
    puts "  User CPU time: #{result.utime.round(2)}s"
    puts "  System CPU time: #{result.stime.round(2)}s"
    puts "  Total CPU time: #{result.total.round(2)}s"
    puts "  Elapsed real time: #{result.real.round(2)}s"

    puts "\n" + "=" * 50
    puts "Testing with all-time records"
    puts "=" * 50

    result2 = Benchmark.measure do
      RecordCalculator.new(scope: "all_time").calculate_and_save!
    end

    puts "\nAll-Time Calculation:"
    puts "  User CPU time: #{result2.utime.round(2)}s"
    puts "  System CPU time: #{result2.stime.round(2)}s"
    puts "  Total CPU time: #{result2.total.round(2)}s"
    puts "  Elapsed real time: #{result2.real.round(2)}s"

    puts "\n" + "=" * 50
    puts "✓ Benchmark complete!"
    puts "=" * 50
  end
end
