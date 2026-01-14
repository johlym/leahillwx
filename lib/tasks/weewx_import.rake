namespace :weewx do
  desc "Import weather data from WeeWX MySQL dump (set USE_API=true to upload via API, UPDATE_RECORDS=true to update existing)"
  task :import, [ :sql_file ] => :environment do |t, args|
    require "tempfile"
    require "net/http"
    require "json"

    sql_file = args[:sql_file] || raise("Usage: rake weewx:import[path/to/dump.sql]")
    sql_file = File.expand_path(sql_file)
    use_api = ENV["USE_API"] == "true"
    update_records = ENV["UPDATE_RECORDS"] == "true"

    unless File.exist?(sql_file)
      puts "Error: File not found: #{sql_file}"
      exit 1
    end

    if use_api
      api_key = ENV["MEASUREMENT_API_KEY"]
      api_url = ENV["API_BASE_URL"] || "http://localhost:3000"

      unless api_key
        puts "Error: MEASUREMENT_API_KEY environment variable required for API upload"
        exit 1
      end
    end

    puts "=" * 80
    puts "WeeWX Data Import"
    puts "=" * 80
    puts "SQL file: #{sql_file}"
    puts "Upload method: #{use_api ? 'API' : 'Direct database'}"
    puts "API URL: #{api_url}" if use_api
    puts "Update mode: #{update_records}"
    puts ""

    # Parse the SQL dump and extract INSERT statements
    puts "Parsing SQL dump..."
    inserts = extract_insert_statements(sql_file)
    puts "Found #{inserts.count} INSERT statements"
    puts ""

    # Process each insert statement
    total_records = 0
    inserts.each_with_index do |insert_sql, idx|
      records = parse_insert_values(insert_sql)
      puts "Processing batch #{idx + 1}/#{inserts.count}: #{records.count} records"

      records.each_slice(1000) do |batch|
        if use_api
          result = import_batch_via_api(batch, api_url, api_key, update_records)
          total_records += result[:created]
          print "  Imported: #{total_records} records (#{result[:skipped]} skipped)\r"
        else
          import_batch(batch, update_records)
          total_records += batch.count
          print "  Imported: #{total_records} records\r"
        end
      end
    end

    puts ""
    puts "=" * 80
    puts "Import Complete: #{total_records} records imported"
    puts "=" * 80
  end

  desc "Clear all weather measurements and reports before reimport"
  task clear_data: :environment do
    print "This will delete ALL weather measurements and reports. Continue? (yes/no): "
    response = STDIN.gets.chomp

    unless response.downcase == "yes"
      puts "Aborted."
      exit 0
    end

    puts "Deleting reports..."
    Report.delete_all

    puts "Deleting weather measurements..."
    WeatherMeasurement.delete_all

    puts "Done. Database cleared."
  end

  private

  def extract_insert_statements(sql_file)
    inserts = []
    current_insert = ""

    File.foreach(sql_file) do |line|
      line = line.strip
      next if line.empty? || line.start_with?("--") || line.start_with?("/*")

      if line =~ /^INSERT INTO/i
        current_insert = line
      elsif !current_insert.empty?
        current_insert += " " + line
      end

      if current_insert.end_with?(";")
        inserts << current_insert
        current_insert = ""
      end
    end

    inserts
  end

  def parse_insert_values(insert_sql)
    # Extract the VALUES portion
    values_match = insert_sql.match(/VALUES\s+(.+);/mi)
    return [] unless values_match

    values_str = values_match[1]
    records = []

    # Split by "),(" to get individual records
    values_str.scan(/\(([^)]+)\)/).each do |match|
      values = match[0].split(",").map(&:strip)
      records << parse_record(values)
    end

    records
  end

  def parse_record(values)
    # WeeWX archive table column order (from schema)
    # 0: dateTime, 1: usUnits, 2: interval, 3: altimeter, 4: appTemp, 5: appTemp1,
    # 6: barometer, 7-14: batteryStatus*, 15: cloudbase, 16-18: co/co2/consBatteryVoltage,
    # 19: dewpoint, 20: dewpoint1, 21: ET, 22-29: extraHumid*, 30-37: extraTemp*,
    # 38-41: forecast/hail/hailBatteryStatus/hailRate, 42-47: heatindex*/heatingTemp/heatingVoltage/humidex*,
    # 48: inDewpoint, 49: inHumidity, 50: inTemp, 51: inTempBatteryStatus,
    # 52-61: leaf/lightning fields, 62: luminosity, 63: maxSolarRad,
    # 64-67: nh3/no2/noise/o3, 68: outHumidity, 69: outTemp, 70: outTempBatteryStatus,
    # 71-74: pb/pm10_0/pm1_0/pm2_5, 75: pressure, 76: radiation, 77: rain,
    # 78: rainBatteryStatus, 79: rainRate, 80-88: referenceVoltage/rxCheckPercent/signal*,
    # 89-93: snow*, 94: so2, 95-102: soilMoist*/soilTemp*,
    # 103: supplyVoltage, 104: txBatteryStatus, 105: UV, 106: uvBatteryStatus,
    # 107: windBatteryStatus, 108: windchill, 109: windDir, 110: windGust,
    # 111: windGustDir, 112: windrun, 113: windSpeed

    date_time = parse_value(values[0])
    us_units = parse_value(values[1])&.to_i || 1  # 1=US, 16=Metric
    barometer = parse_value(values[6])      # Column 7 in 1-indexed schema
    out_humidity = parse_value(values[67])  # Column 68 in 1-indexed schema
    out_temp = parse_value(values[68])      # Column 69 in 1-indexed schema
    pressure = parse_value(values[74])      # Column 75 in 1-indexed schema
    radiation = parse_value(values[75])     # Column 76 in 1-indexed schema
    rain = parse_value(values[76])          # Column 77 in 1-indexed schema
    rain_rate = parse_value(values[78])     # Column 79 in 1-indexed schema
    luminosity = parse_value(values[61])    # Column 62 in 1-indexed schema
    uv = parse_value(values[105])           # Column 106 in 1-indexed schema
    wind_dir = parse_value(values[109])     # Column 110 in 1-indexed schema
    wind_gust = parse_value(values[110])    # Column 111 in 1-indexed schema
    wind_speed = parse_value(values[113])   # Column 114 in 1-indexed schema

    # Convert US units to metric if needed (usUnits=1 means US: F, inHg, mph, inches)
    is_us_units = (us_units == 1)

    out_temp_c = is_us_units ? fahrenheit_to_celsius(out_temp&.to_f) : out_temp&.to_f
    pressure_mbar = is_us_units ? inhg_to_mbar(pressure&.to_f) : pressure&.to_f
    barometer_mbar = is_us_units ? inhg_to_mbar(barometer&.to_f) : barometer&.to_f
    wind_gust_ms = is_us_units ? mph_to_ms(wind_gust&.to_f) : wind_gust&.to_f
    wind_speed_ms = is_us_units ? mph_to_ms(wind_speed&.to_f) : wind_speed&.to_f
    rain_mm = is_us_units ? inches_to_mm(rain&.to_f) : rain&.to_f
    rain_rate_mm = is_us_units ? inches_to_mm(rain_rate&.to_f) : rain_rate&.to_f

    {
      reading_date_time: Time.at(date_time.to_i).utc,
      barometer_abs: pressure_mbar || 0.0,
      barometer_rel: barometer_mbar || 0.0,
      gust_speed: wind_gust_ms || 0.0,
      humidity: out_humidity&.to_i || 0,
      light: (radiation || luminosity)&.to_f || 0.0,
      rain_day: rain_mm || 0.0,
      rain_rate: rain_rate_mm || 0.0,
      temperature: out_temp_c || 0.0,
      uv: uv&.to_i || 0,
      uvi: uv&.to_f || 0.0,
      wind_dir: wind_dir&.to_i || 0,
      wind_speed: wind_speed_ms || 0.0
    }
  end

  def parse_value(str)
    return nil if str.nil? || str == "NULL"
    str.gsub(/['"]/, "").strip
  end

  # Unit conversion methods
  def fahrenheit_to_celsius(f)
    return nil if f.nil?
    (f - 32.0) * 5.0 / 9.0
  end

  def inhg_to_mbar(inhg)
    return nil if inhg.nil?
    inhg * 33.8639
  end

  def mph_to_ms(mph)
    return nil if mph.nil?
    mph * 0.44704
  end

  def inches_to_mm(inches)
    return nil if inches.nil?
    inches * 25.4
  end

  def import_batch(batch, update_records = false)
    if update_records
      # Use upsert to update existing records or insert new ones
      WeatherMeasurement.upsert_all(
        batch,
        unique_by: :reading_date_time,
        record_timestamps: true
      )
    else
      # Check for existing records
      timestamps = batch.map { |r| r[:reading_date_time] }
      existing_timestamps = WeatherMeasurement.where(reading_date_time: timestamps).pluck(:reading_date_time).to_set

      # Filter out duplicates
      new_records = batch.reject do |record|
        if existing_timestamps.include?(record[:reading_date_time])
          Rails.logger.info("Skipping duplicate measurement at #{record[:reading_date_time]}")
          true
        else
          false
        end
      end

      # Log duplicate count if any
      if new_records.size < batch.size
        duplicates_count = batch.size - new_records.size
        puts "  (skipped #{duplicates_count} duplicates)"
      end

      # Insert only new records
      WeatherMeasurement.insert_all!(new_records, record_timestamps: true) if new_records.any?
    end
  rescue => e
    puts "\nWarning: Error importing batch: #{e.message}"
    Rails.logger.error("Error in import batch: #{e.message}")
  end

  def import_batch_via_api(batch, api_url, api_key, update_records = false)
    uri = URI("#{api_url}/api/v1/weather_measurement/bulk")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri.path)
    request["Authorization"] = "Bearer #{api_key}"
    request["Content-Type"] = "application/json"

    body = { weather_measurements: batch }
    body[:update_records] = true if update_records
    request.body = body.to_json

    response = http.request(request)

    if response.code.to_i >= 200 && response.code.to_i < 300
      result = JSON.parse(response.body)
      # API now returns 202 Accepted with background job queued
      { created: result["accepted"] || 0, skipped: 0 }
    else
      puts "\nError from API: #{response.code} - #{response.body}"
      raise "API upload failed"
    end
  rescue => e
    puts "\nError uploading batch via API: #{e.message}"
    raise
  end
end
