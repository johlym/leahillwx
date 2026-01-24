class RecordCalculator
  def initialize(scope:, year: nil)
    @scope = scope
    @year = year
    @record = Record.find_or_initialize_by(scope: scope, year: year)
  end

  def calculate_and_save!
    Rails.logger.info "Starting record calculation for #{@scope} #{@year || 'all-time'}"

    calculate_temperature_records
    GC.start
    Rails.logger.info "✓ Temperature records calculated"

    calculate_wind_records
    GC.start
    Rails.logger.info "✓ Wind records calculated"

    calculate_rain_records
    GC.start
    Rails.logger.info "✓ Rain records calculated"

    calculate_humidity_records
    GC.start
    Rails.logger.info "✓ Humidity records calculated"

    calculate_barometer_records
    GC.start
    Rails.logger.info "✓ Barometer records calculated"

    calculate_sun_records
    GC.start
    Rails.logger.info "✓ Sun records calculated"

    @record.save!
    Rails.logger.info "✓ Record saved successfully"
    @record
  end

  private

  def measurements
    base = WeatherMeasurement.all
    if @scope == "yearly" && @year
      query = base.where("EXTRACT(YEAR FROM reading_date_time) = ?", @year)
      if @year == Time.current.year
        query = query.where("DATE(reading_date_time) < ?", Time.current.in_time_zone("America/Los_Angeles").to_date)
      end
      query
    else
      base
    end
  end

  def calculate_temperature_records
    # Only select needed fields to reduce memory
    highest = measurements.select(:temperature, :reading_date_time).order(temperature: :desc).limit(1).first
    @record.highest_temp = highest&.temperature
    @record.highest_temp_at = highest&.reading_date_time

    lowest = measurements.select(:temperature, :reading_date_time).order(temperature: :asc).limit(1).first
    @record.lowest_temp = lowest&.temperature
    @record.lowest_temp_at = lowest&.reading_date_time

    highest_apparent = measurements
      .select(:temperature, :humidity, :wind_speed, :reading_date_time)
      .order(Arel.sql("temperature - ((100 - humidity) / 5.0)"))
      .reverse_order
      .limit(1)
      .first
    if highest_apparent
      @record.highest_apparent_temp = highest_apparent.feels_like
      @record.highest_apparent_temp_at = highest_apparent.reading_date_time
    end

    lowest_apparent = measurements
      .select(:temperature, :humidity, :wind_speed, :reading_date_time)
      .order(Arel.sql("temperature - ((100 - humidity) / 5.0)"))
      .limit(1)
      .first
    if lowest_apparent
      @record.lowest_apparent_temp = lowest_apparent.feels_like
      @record.lowest_apparent_temp_at = lowest_apparent.reading_date_time
    end

    highest_heat_index = measurements
      .select(:temperature, :humidity, :wind_speed, :reading_date_time)
      .where("temperature > 27")
      .where("humidity >= 40")
      .order(Arel.sql("temperature - ((100 - humidity) / 5.0)"))
      .reverse_order
      .limit(1)
      .first
    if highest_heat_index
      @record.highest_heat_index = highest_heat_index.feels_like
      @record.highest_heat_index_at = highest_heat_index.reading_date_time
    end

    lowest_wind_chill = measurements
      .select(:temperature, :humidity, :wind_speed, :reading_date_time)
      .where("temperature < 10")
      .where("wind_speed > 1.34")
      .order(Arel.sql("temperature - ((100 - humidity) / 5.0)"))
      .limit(1)
      .first
    if lowest_wind_chill
      @record.lowest_wind_chill = lowest_wind_chill.feels_like
      @record.lowest_wind_chill_at = lowest_wind_chill.reading_date_time
    end

    # Use ReportEntry for daily temperature ranges
    largest_range = if @scope == "yearly" && @year
      ReportEntry.joins(:report)
        .where(reports: { year: @year })
        .where.not(high_temp: nil, low_temp: nil)
        .select("report_entries.*, (high_temp - low_temp) as temp_range")
        .order("temp_range DESC")
        .limit(1)
        .first
    else
      ReportEntry.where.not(high_temp: nil, low_temp: nil)
        .select("report_entries.*, (high_temp - low_temp) as temp_range")
        .order("temp_range DESC")
        .limit(1)
        .first
    end

    if largest_range
      @record.largest_temp_range = largest_range.high_temp - largest_range.low_temp
      @record.largest_temp_range_date = Date.new(largest_range.report.year, largest_range.report.month, largest_range.day)
    end

    smallest_range = if @scope == "yearly" && @year
      ReportEntry.joins(:report)
        .where(reports: { year: @year })
        .where.not(high_temp: nil, low_temp: nil)
        .select("report_entries.*, (high_temp - low_temp) as temp_range")
        .order("temp_range ASC")
        .limit(1)
        .first
    else
      ReportEntry.where.not(high_temp: nil, low_temp: nil)
        .select("report_entries.*, (high_temp - low_temp) as temp_range")
        .order("temp_range ASC")
        .limit(1)
        .first
    end

    if smallest_range
      @record.smallest_temp_range = smallest_range.high_temp - smallest_range.low_temp
      @record.smallest_temp_range_date = Date.new(smallest_range.report.year, smallest_range.report.month, smallest_range.day)
    end
  end

  def calculate_wind_records
    strongest = measurements.select(:gust_speed, :reading_date_time).order(gust_speed: :desc).limit(1).first
    @record.strongest_gust = strongest&.gust_speed
    @record.strongest_gust_at = strongest&.reading_date_time

    highest_run = measurements
      .select("DATE(reading_date_time) as date, SUM(wind_speed * 2.23694 / 60.0 * 5) as wind_run_miles")
      .group("DATE(reading_date_time)")
      .order("wind_run_miles DESC")
      .limit(1)
      .first

    if highest_run
      @record.highest_wind_run = highest_run.wind_run_miles
      @record.highest_wind_run_date = highest_run.date
    end
  end

  def calculate_rain_records
    # Use ReportEntry table for daily totals instead of raw measurements
    highest_daily = if @scope == "yearly" && @year
      ReportEntry.joins(:report)
        .where(reports: { year: @year })
        .where.not(rain: nil)
        .order(rain: :desc)
        .limit(1)
        .first
    else
      ReportEntry.where.not(rain: nil)
        .order(rain: :desc)
        .limit(1)
        .first
    end

    if highest_daily
      @record.highest_daily_rain = highest_daily.rain
      # Construct date from report's year/month and entry's day
      @record.highest_daily_rain_date = Date.new(highest_daily.report.year, highest_daily.report.month, highest_daily.day)
    end

    highest_rate = measurements.select(:rain_rate, :reading_date_time).order(rain_rate: :desc).limit(1).first
    @record.highest_rain_rate = highest_rate&.rain_rate
    @record.highest_rain_rate_at = highest_rate&.reading_date_time

    # Use Report table for monthly totals instead of raw measurements
    wettest = if @scope == "yearly" && @year
      Report.where(year: @year).order(total_rain: :desc).limit(1).first
    else
      Report.order(total_rain: :desc).limit(1).first
    end

    if wettest && wettest.total_rain.present?
      @record.wettest_month = wettest.month
      @record.wettest_month_year = wettest.year
      @record.wettest_month_total = wettest.total_rain
    end

    consecutive_rain = find_consecutive_rain_days
    if consecutive_rain[:wet]
      @record.consecutive_rain_days = consecutive_rain[:wet][:days]
      @record.consecutive_rain_start_date = consecutive_rain[:wet][:start_date]
    end

    if consecutive_rain[:dry]
      @record.consecutive_dry_days = consecutive_rain[:dry][:days]
      @record.consecutive_dry_start_date = consecutive_rain[:dry][:start_date]
    end
  end

  def find_consecutive_rain_days
    longest_wet = { days: 0, start_date: nil }
    longest_dry = { days: 0, start_date: nil }
    current_wet = { days: 0, start_date: nil }
    current_dry = { days: 0, start_date: nil }

    # Use ReportEntry data for daily rain totals
    daily_data = if @scope == "yearly" && @year
      ReportEntry.joins(:report)
        .where(reports: { year: @year })
        .where.not(day: nil)
        .order("reports.year ASC, reports.month ASC, report_entries.day ASC")
        .pluck(Arel.sql("CAST(reports.year || '-' || LPAD(reports.month::text, 2, '0') || '-' || LPAD(report_entries.day::text, 2, '0') AS DATE)"), :rain)
    else
      ReportEntry.joins(:report)
        .where.not(day: nil)
        .order("reports.year ASC, reports.month ASC, report_entries.day ASC")
        .pluck(Arel.sql("CAST(reports.year || '-' || LPAD(reports.month::text, 2, '0') || '-' || LPAD(report_entries.day::text, 2, '0') AS DATE)"), :rain)
    end

    daily_data.each do |date, daily_total|
      if daily_total.to_f > 0
        if current_wet[:days] == 0
          current_wet[:start_date] = date
          current_wet[:days] = 1
        else
          current_wet[:days] += 1
        end

        if current_dry[:days] > longest_dry[:days]
          longest_dry = current_dry.dup
        end
        current_dry = { days: 0, start_date: nil }
      else
        if current_dry[:days] == 0
          current_dry[:start_date] = date
          current_dry[:days] = 1
        else
          current_dry[:days] += 1
        end

        if current_wet[:days] > longest_wet[:days]
          longest_wet = current_wet.dup
        end
        current_wet = { days: 0, start_date: nil }
      end
    end

    if current_wet[:days] > longest_wet[:days]
      longest_wet = current_wet
    end
    if current_dry[:days] > longest_dry[:days]
      longest_dry = current_dry
    end

    { wet: longest_wet[:days] > 0 ? longest_wet : nil, dry: longest_dry[:days] > 0 ? longest_dry : nil }
  end

  def calculate_humidity_records
    highest = measurements.select(:humidity, :reading_date_time).order(humidity: :desc).limit(1).first
    @record.highest_humidity = highest&.humidity
    @record.highest_humidity_at = highest&.reading_date_time

    lowest = measurements.select(:humidity, :reading_date_time).order(humidity: :asc).limit(1).first
    @record.lowest_humidity = lowest&.humidity
    @record.lowest_humidity_at = lowest&.reading_date_time

    highest_dew = measurements
      .select(:temperature, :humidity, :reading_date_time)
      .order(Arel.sql("temperature - ((100 - humidity) / 5.0)"))
      .reverse_order
      .limit(1)
      .first
    if highest_dew
      @record.highest_dew_point = highest_dew.dew_point
      @record.highest_dew_point_at = highest_dew.reading_date_time
    end

    lowest_dew = measurements
      .select(:temperature, :humidity, :reading_date_time)
      .order(Arel.sql("temperature - ((100 - humidity) / 5.0)"))
      .limit(1)
      .first
    if lowest_dew
      @record.lowest_dew_point = lowest_dew.dew_point
      @record.lowest_dew_point_at = lowest_dew.reading_date_time
    end
  end

  def calculate_barometer_records
    highest = measurements.select(:barometer_rel, :reading_date_time).order(barometer_rel: :desc).limit(1).first
    @record.highest_pressure = highest&.barometer_rel
    @record.highest_pressure_at = highest&.reading_date_time

    lowest = measurements.select(:barometer_rel, :reading_date_time).order(barometer_rel: :asc).limit(1).first
    @record.lowest_pressure = lowest&.barometer_rel
    @record.lowest_pressure_at = lowest&.reading_date_time

    largest_swing = measurements
      .select("DATE(reading_date_time) as date, MAX(barometer_rel) - MIN(barometer_rel) as pressure_swing")
      .group("DATE(reading_date_time)")
      .order("pressure_swing DESC")
      .limit(1)
      .first

    if largest_swing
      @record.largest_pressure_swing = largest_swing.pressure_swing
      @record.largest_pressure_swing_date = largest_swing.date
    end
  end

  def calculate_sun_records
    highest = measurements.select(:light, :reading_date_time).order(light: :desc).limit(1).first
    @record.highest_solar = highest&.light
    @record.highest_solar_at = highest&.reading_date_time
  end
end
