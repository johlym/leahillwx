#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require "net/http"
require "json"
require "time"

# WeeWX MySQL Import Script
# Parses a MySQL dump file and imports weather measurements via the API

class WeewxImporter
  # Cutoff: 2026-01-05 00:15:02 UTC (first record in new DB)
  CUTOFF_TIMESTAMP = 1736064902

  # Elevation for sea-level pressure calculation (416 feet)
  ELEVATION_FEET = 416

  # Batch size for bulk API calls (max 1000)
  BATCH_SIZE = 1000

  # WeeWX column order from schema (0-indexed positions)
  WEEWX_COLUMNS = {
    dateTime: 0,
    usUnits: 1,
    interval: 2,
    pressure: 74,
    radiation: 75,
    rain: 77,
    rainRate: 78,
    outHumidity: 67,
    outTemp: 68,
    UV: 105,
    windDir: 108,
    windGust: 109,
    windSpeed: 112
  }.freeze

  def initialize(path:, api_url:, api_key:, dry_run: false)
    @path = path
    @api_url = api_url
    @api_key = api_key
    @dry_run = dry_run
    @stats = { processed: 0, skipped: 0, imported: 0, errors: 0 }
  end

  def run
    puts "WeeWX Import Script"
    puts "=" * 50
    puts "Source file: #{@path}"
    puts "API URL: #{@api_url}"
    puts "Dry run: #{@dry_run}"
    puts "Cutoff: #{Time.at(CUTOFF_TIMESTAMP).utc}"
    puts "=" * 50
    puts

    unless File.exist?(@path)
      puts "ERROR: File not found: #{@path}"
      exit 1
    end

    records = parse_sql_file
    puts "Parsed #{records.length} records from SQL file"

    # Filter by cutoff
    puts "Filtering records before cutoff..."
    records = records.select { |r| r[:dateTime] < CUTOFF_TIMESTAMP }
    puts "  #{records.length} records before cutoff date"
    puts

    puts "Sorting records by timestamp..."

    # Sort by timestamp
    records.sort_by! { |r| r[:dateTime] }
    puts "  Done. First: #{Time.at(records.first[:dateTime]).utc}" if records.any?
    puts "  Done. Last: #{Time.at(records.last[:dateTime]).utc}" if records.any?
    puts

    total_batches = (records.length.to_f / BATCH_SIZE).ceil
    puts "Starting import (#{total_batches} batches of up to #{BATCH_SIZE} records)..."
    puts

    # Process in batches
    records.each_slice(BATCH_SIZE).with_index do |batch, batch_index|
      puts "Processing batch #{batch_index + 1} (#{batch.length} records)..."

      measurements = batch.map { |r| transform_record(r) }

      if @dry_run
        puts "  [DRY RUN] Would import #{measurements.length} records"
        @stats[:imported] += measurements.length
      else
        import_batch(measurements, batch_index)
      end
    end

    puts
    puts "=" * 50
    puts "Import Complete"
    puts "  Processed: #{@stats[:processed]}"
    puts "  Skipped (nil values): #{@stats[:skipped]}"
    puts "  Imported: #{@stats[:imported]}"
    puts "  Errors: #{@stats[:errors]}"
    puts "=" * 50
  end

  private

  def parse_sql_file
    records = []
    line_count = 0
    insert_count = 0

    puts "Parsing SQL file..."

    File.foreach(@path) do |line|
      line_count += 1
      print "\r  Lines read: #{line_count}" if (line_count % 10_000).zero?
      next unless line.start_with?("INSERT INTO `archive`")

      insert_count += 1
      print "\r  Lines read: #{line_count}, INSERT statements: #{insert_count}"

      # Extract values from INSERT statement
      # Format: INSERT INTO `archive` VALUES (val1,val2,...),(val1,val2,...),...;
      values_section = line.match(/VALUES\s*(.+);?\s*$/i)&.[](1)
      next unless values_section

      # Split into individual record tuples
      # Handle parentheses-wrapped value sets
      values_section.scan(/\(([^)]+)\)/) do |match|
        values = parse_values(match[0])
        record = extract_weewx_record(values)
        records << record if record
      end
    end

    puts "\r  Lines read: #{line_count}, INSERT statements: #{insert_count}"
    puts "  Records extracted: #{records.length}"
    records
  end

  def parse_values(values_str)
    # Parse comma-separated values, handling NULL
    values_str.split(",").map do |v|
      v = v.strip
      case v
      when "NULL" then nil
      when /\A-?\d+\z/ then v.to_i
      when /\A-?\d+\.\d+\z/ then v.to_f
      else v.delete('"\'')
      end
    end
  end

  def extract_weewx_record(values)
    record = {}
    WEEWX_COLUMNS.each do |col, idx|
      record[col] = values[idx] if idx < values.length
    end

    # Skip if essential fields are missing
    return nil if record[:dateTime].nil?

    @stats[:processed] += 1
    record
  end

  def transform_record(record)
    @stats[:skipped] += 1 if record[:outTemp].nil? || record[:outHumidity].nil?

    # Unit conversions (US customary → metric)
    temperature = convert_temp_f_to_c(record[:outTemp])
    barometer_abs = convert_inhg_to_hpa(record[:pressure])
    barometer_rel = calculate_sea_level_pressure(barometer_abs)
    wind_speed = convert_mph_to_ms(record[:windSpeed])
    gust_speed = convert_mph_to_ms(record[:windGust])
    rain_day = convert_in_to_mm(record[:rain])
    rain_rate = convert_in_to_mm(record[:rainRate])
    light = convert_radiation_to_lux(record[:radiation])

    {
      reading_date_time: Time.at(record[:dateTime]).utc.iso8601,
      barometer_abs: barometer_abs || 0,
      barometer_rel: barometer_rel || 0,
      gust_speed: gust_speed || 0,
      humidity: (record[:outHumidity] || 0).round.to_i,
      light: light || 0,
      rain_day: rain_day || 0,
      rain_rate: rain_rate || 0,
      temperature: temperature || 0,
      uv: (record[:UV] || 0).round.to_i,
      uvi: 0,
      wind_dir: (record[:windDir] || 0).round.to_i,
      wind_speed: wind_speed || 0
    }
  end

  # Temperature: °F → °C
  def convert_temp_f_to_c(fahrenheit)
    return nil if fahrenheit.nil?
    ((fahrenheit - 32) * 5.0 / 9.0).round(2)
  end

  # Pressure: inHg → hPa
  def convert_inhg_to_hpa(inhg)
    return nil if inhg.nil?
    (inhg * 33.8639).round(2)
  end

  # Calculate sea-level pressure from station pressure
  # Adjustment: ~1 hPa per 10m (~30ft) of elevation
  def calculate_sea_level_pressure(station_pressure_hpa)
    return nil if station_pressure_hpa.nil?
    elevation_meters = ELEVATION_FEET * 0.3048
    adjustment = elevation_meters / 10.0 # ~1 hPa per 10m
    (station_pressure_hpa + adjustment).round(2)
  end

  # Wind speed: mph → m/s
  def convert_mph_to_ms(mph)
    return nil if mph.nil?
    (mph * 0.44704).round(2)
  end

  # Rain: inches → mm
  def convert_in_to_mm(inches)
    return nil if inches.nil?
    (inches * 25.4).round(2)
  end

  # Radiation: W/m² → lux
  def convert_radiation_to_lux(radiation)
    return 0 if radiation.nil? || radiation == 0
    (radiation / 0.0084).round(2)
  end

  def import_batch(measurements, batch_index)
    uri = URI.parse("#{@api_url}/api/v1/weather_measurement/bulk")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"

    request = Net::HTTP::Post.new(uri.path)
    request["Content-Type"] = "application/json"
    request["Authorization"] = "Bearer #{@api_key}"
    request.body = { weather_measurements: measurements }.to_json

    response = http.request(request)

    case response.code.to_i
    when 201
      result = JSON.parse(response.body)
      @stats[:imported] += result["created"]
      puts "  ✓ Batch #{batch_index + 1}: #{result['created']} records imported"
    when 422
      result = JSON.parse(response.body)
      @stats[:errors] += result["errors"]&.length || 1
      puts "  ✗ Batch #{batch_index + 1}: Validation errors"
      puts "    #{result['errors']&.first(3)&.inspect}"
    else
      @stats[:errors] += measurements.length
      puts "  ✗ Batch #{batch_index + 1}: HTTP #{response.code} - #{response.body[0..200]}"
    end
  rescue StandardError => e
    @stats[:errors] += measurements.length
    puts "  ✗ Batch #{batch_index + 1}: #{e.message}"
  end
end

# CLI
options = {
  api_url: ENV.fetch("API_URL", "http://localhost:3000"),
  api_key: ENV.fetch("API_KEY", nil),
  dry_run: false
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} --path <sql_file> [options]"

  opts.on("--path PATH", "Path to MySQL dump file (required)") do |v|
    options[:path] = v
  end

  opts.on("--api-url URL", "API base URL (default: http://localhost:3000)") do |v|
    options[:api_url] = v
  end

  opts.on("--api-key KEY", "API key for authentication") do |v|
    options[:api_key] = v
  end

  opts.on("--dry-run", "Parse and transform without making API calls") do
    options[:dry_run] = true
  end

  opts.on("-h", "--help", "Show this help") do
    puts opts
    exit
  end
end.parse!

if options[:path].nil?
  puts "ERROR: --path is required"
  puts "Use --help for usage information"
  exit 1
end

if options[:api_key].nil? && !options[:dry_run]
  puts "ERROR: --api-key is required (or set API_KEY env var)"
  puts "Use --dry-run to test without API calls"
  exit 1
end

importer = WeewxImporter.new(
  path: options[:path],
  api_url: options[:api_url],
  api_key: options[:api_key],
  dry_run: options[:dry_run]
)

importer.run
