class RecordCalculator
  def initialize(scope:, year: nil)
    @scope = scope
    @year = year
    @record = Record.find_or_initialize_by(scope: scope, year: year)
  end

  def calculate_and_save!
    Parallel.each([
      :calculate_temperature_records,
      :calculate_wind_records,
      :calculate_rain_records,
      :calculate_humidity_records,
      :calculate_barometer_records,
      :calculate_sun_records
    ], in_threads: 6) do |method_name|
      send(method_name)
    end

    @record.save!
    @record
  end

  private

  def measurements
    @measurements ||= begin
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
  end

  def calculate_temperature_records
    highest = measurements.order(temperature: :desc).first
    @record.highest_temp = highest&.temperature
    @record.highest_temp_at = highest&.reading_date_time

    lowest = measurements.order(temperature: :asc).first
    @record.lowest_temp = lowest&.temperature
    @record.lowest_temp_at = lowest&.reading_date_time

    highest_apparent = measurements.order(Arel.sql("temperature - ((100 - humidity) / 5.0)")).reverse_order.first
    if highest_apparent
      @record.highest_apparent_temp = highest_apparent.feels_like
      @record.highest_apparent_temp_at = highest_apparent.reading_date_time
    end

    lowest_apparent = measurements.order(Arel.sql("temperature - ((100 - humidity) / 5.0)")).first
    if lowest_apparent
      @record.lowest_apparent_temp = lowest_apparent.feels_like
      @record.lowest_apparent_temp_at = lowest_apparent.reading_date_time
    end

    highest_heat_index = measurements.where("temperature > 27").where("humidity >= 40").order(Arel.sql("temperature - ((100 - humidity) / 5.0)")).reverse_order.first
    if highest_heat_index
      @record.highest_heat_index = highest_heat_index.feels_like
      @record.highest_heat_index_at = highest_heat_index.reading_date_time
    end

    lowest_wind_chill = measurements.where("temperature < 10").where("wind_speed > 1.34").order(Arel.sql("temperature - ((100 - humidity) / 5.0)")).first
    if lowest_wind_chill
      @record.lowest_wind_chill = lowest_wind_chill.feels_like
      @record.lowest_wind_chill_at = lowest_wind_chill.reading_date_time
    end

    daily_ranges = measurements
      .select("DATE(reading_date_time) as date, MAX(temperature) - MIN(temperature) as temp_range")
      .group("DATE(reading_date_time)")
      .order("temp_range DESC")

    largest_range = daily_ranges.first
    if largest_range
      @record.largest_temp_range = largest_range.temp_range
      @record.largest_temp_range_date = largest_range.date
    end

    smallest_range = daily_ranges.reverse_order.first
    if smallest_range
      @record.smallest_temp_range = smallest_range.temp_range
      @record.smallest_temp_range_date = smallest_range.date
    end
  end

  def calculate_wind_records
    strongest = measurements.order(gust_speed: :desc).first
    @record.strongest_gust = strongest&.gust_speed
    @record.strongest_gust_at = strongest&.reading_date_time

    daily_wind_runs = measurements
      .select("DATE(reading_date_time) as date, SUM(wind_speed * 2.23694 / 60.0 * 5) as wind_run_miles")
      .group("DATE(reading_date_time)")
      .order("wind_run_miles DESC")

    highest_run = daily_wind_runs.first
    if highest_run
      @record.highest_wind_run = highest_run.wind_run_miles
      @record.highest_wind_run_date = highest_run.date
    end

    calm_periods = find_longest_calm_period
    if calm_periods
      @record.longest_calm_hours = calm_periods[:hours]
      @record.longest_calm_start_at = calm_periods[:start_at]
    end
  end

  def find_longest_calm_period
    calm_measurements = measurements.where(wind_speed: 0).order(:reading_date_time)
    return nil if calm_measurements.empty?

    longest = { hours: 0, start_at: nil }
    current = { start_at: nil, count: 0 }

    calm_measurements.each do |m|
      if current[:start_at].nil?
        current[:start_at] = m.reading_date_time
        current[:count] = 1
      elsif (m.reading_date_time - current[:start_at]) / 1.hour <= current[:count] * 1.2
        current[:count] += 1
      else
        if current[:count] > longest[:hours]
          longest[:hours] = current[:count]
          longest[:start_at] = current[:start_at]
        end
        current[:start_at] = m.reading_date_time
        current[:count] = 1
      end
    end

    if current[:count] > longest[:hours]
      longest[:hours] = current[:count]
      longest[:start_at] = current[:start_at]
    end

    longest[:hours] > 0 ? longest : nil
  end

  def calculate_rain_records
    daily_rain = measurements
      .select("DATE(reading_date_time) as date, MAX(rain_day) as daily_total")
      .group("DATE(reading_date_time)")
      .order("daily_total DESC")

    highest_daily = daily_rain.first
    if highest_daily
      @record.highest_daily_rain = highest_daily.daily_total
      @record.highest_daily_rain_date = highest_daily.date
    end

    highest_rate = measurements.order(rain_rate: :desc).first
    @record.highest_rain_rate = highest_rate&.rain_rate
    @record.highest_rain_rate_at = highest_rate&.reading_date_time

    monthly_totals = measurements
      .select("EXTRACT(YEAR FROM reading_date_time) as year, EXTRACT(MONTH FROM reading_date_time) as month, MAX(rain_day) as total")
      .group("EXTRACT(YEAR FROM reading_date_time), EXTRACT(MONTH FROM reading_date_time)")
      .order("total DESC")

    wettest = monthly_totals.first
    if wettest
      @record.wettest_month = wettest.month.to_i
      @record.wettest_month_year = wettest.year.to_i
      @record.wettest_month_total = wettest.total
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
    daily_rain = measurements
      .select("DATE(reading_date_time) as date, MAX(rain_day) as daily_total")
      .group("DATE(reading_date_time)")
      .order("date ASC")

    longest_wet = { days: 0, start_date: nil }
    longest_dry = { days: 0, start_date: nil }
    current_wet = { days: 0, start_date: nil }
    current_dry = { days: 0, start_date: nil }

    daily_rain.each do |day|
      if day.daily_total > 0
        if current_wet[:days] == 0
          current_wet[:start_date] = day.date
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
          current_dry[:start_date] = day.date
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
    highest = measurements.order(humidity: :desc).first
    @record.highest_humidity = highest&.humidity
    @record.highest_humidity_at = highest&.reading_date_time

    lowest = measurements.order(humidity: :asc).first
    @record.lowest_humidity = lowest&.humidity
    @record.lowest_humidity_at = lowest&.reading_date_time

    highest_dew = measurements.order(Arel.sql("temperature - ((100 - humidity) / 5.0)")).reverse_order.first
    if highest_dew
      @record.highest_dew_point = highest_dew.dew_point
      @record.highest_dew_point_at = highest_dew.reading_date_time
    end

    lowest_dew = measurements.order(Arel.sql("temperature - ((100 - humidity) / 5.0)")).first
    if lowest_dew
      @record.lowest_dew_point = lowest_dew.dew_point
      @record.lowest_dew_point_at = lowest_dew.reading_date_time
    end
  end

  def calculate_barometer_records
    highest = measurements.order(barometer_rel: :desc).first
    @record.highest_pressure = highest&.barometer_rel
    @record.highest_pressure_at = highest&.reading_date_time

    lowest = measurements.order(barometer_rel: :asc).first
    @record.lowest_pressure = lowest&.barometer_rel
    @record.lowest_pressure_at = lowest&.reading_date_time

    daily_swings = measurements
      .select("DATE(reading_date_time) as date, MAX(barometer_rel) - MIN(barometer_rel) as pressure_swing")
      .group("DATE(reading_date_time)")
      .order("pressure_swing DESC")

    largest_swing = daily_swings.first
    if largest_swing
      @record.largest_pressure_swing = largest_swing.pressure_swing
      @record.largest_pressure_swing_date = largest_swing.date
    end
  end

  def calculate_sun_records
    highest = measurements.order(light: :desc).first
    @record.highest_solar = highest&.light
    @record.highest_solar_at = highest&.reading_date_time
  end
end
