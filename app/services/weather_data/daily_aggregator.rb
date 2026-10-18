module WeatherData
  class DailyAggregator
    include WeatherUnitConversions
    include WindVectorAveraging

    EXPECTED_MEASUREMENTS_PER_DAY = 1440

    attr_reader :date, :measurements

    def initialize(date)
      @date = date.is_a?(Date) ? date : Date.parse(date.to_s)
      @measurements = fetch_measurements
    end

    def aggregate
      report = find_or_create_report
      entry = create_or_update_entry(report)
      sync_hourly_rain(report)

      WeatherData::MonthlyStatsCalculator.new(report).calculate

      entry
    end

    private

    def fetch_measurements
      start_time = @date.in_time_zone("America/Los_Angeles").beginning_of_day
      end_time = @date.in_time_zone("America/Los_Angeles").end_of_day

      WeatherMeasurement.where(reading_date_time: start_time..end_time)
                       .order(:reading_date_time)
    end

    def find_or_create_report
      Report.find_or_create_by!(year: @date.year, month: @date.month)
    end

    def create_or_update_entry(report)
      entry = report.entries.find_or_initialize_by(day: @date.day, hour: nil)

      if measurements.empty?
        entry.assign_attributes(no_data_attributes)
      else
        entry.assign_attributes(calculate_daily_stats)
        entry.partial_period = partial_day?
      end

      entry.save!
      entry
    end

    def no_data_attributes
      {
        mean_temp: nil,
        high_temp: nil,
        high_temp_time: nil,
        low_temp: nil,
        low_temp_time: nil,
        heat_degree_days: nil,
        cool_degree_days: nil,
        rain: nil,
        avg_wind_speed: nil,
        high_wind_speed: nil,
        high_wind_time: nil,
        wind_dir: nil,
        wind_dir_compass: nil,
        mean_pressure: nil,
        high_pressure: nil,
        high_pressure_time: nil,
        low_pressure: nil,
        low_pressure_time: nil,
        partial_period: false
      }
    end

    def calculate_daily_stats
      temps_c = measurements.map(&:temperature)
      mean_temp_c = temps_c.sum / temps_c.size

      high_measurement = measurements.max_by(&:temperature)
      low_measurement = measurements.min_by(&:temperature)
      gust_measurement = measurements.max_by(&:gust_speed)
      high_pressure_measurement = measurements.max_by(&:sea_level_pressure_qff)
      low_pressure_measurement = measurements.min_by(&:sea_level_pressure_qff)

      wind_dir_degrees = self.class.calculate_dominant_wind_direction(measurements)
      wind_dir_compass = degrees_to_compass(wind_dir_degrees)

      wind_speeds_mps = measurements.map(&:wind_speed)
      avg_wind_speed_mps = wind_speeds_mps.sum / wind_speeds_mps.size

      pressures = measurements.map(&:sea_level_pressure_qff)
      mean_pressure = pressures.sum / pressures.size

      # Match the homepage: the station's counter at the last reading, not the
      # peak. A spike or a pre-reset carryover from yesterday must not stick.
      total_rain_mm = rain_attribution.total_mm

      # Convert mean temp to Fahrenheit for degree day calculations
      mean_temp_f = celsius_to_fahrenheit(mean_temp_c)

      {
        mean_temp: mean_temp_c,
        high_temp: high_measurement.temperature,
        high_temp_time: format_time(high_measurement.reading_date_time),
        low_temp: low_measurement.temperature,
        low_temp_time: format_time(low_measurement.reading_date_time),
        heat_degree_days: calculate_heat_degree_days(mean_temp_f),
        cool_degree_days: calculate_cool_degree_days(mean_temp_f),
        rain: total_rain_mm,
        avg_wind_speed: avg_wind_speed_mps,
        high_wind_speed: gust_measurement.gust_speed,
        high_wind_time: format_time(gust_measurement.reading_date_time),
        wind_dir: wind_dir_degrees,
        wind_dir_compass: wind_dir_compass,
        mean_pressure: mean_pressure,
        high_pressure: high_pressure_measurement.sea_level_pressure_qff,
        high_pressure_time: format_time(high_pressure_measurement.reading_date_time),
        low_pressure: low_pressure_measurement.sea_level_pressure_qff,
        low_pressure_time: format_time(low_pressure_measurement.reading_date_time)
      }
    end

    def rain_attribution
      @rain_attribution ||= WeatherData::RainTotal.attribute(
        measurements.to_a,
        baseline: rain_baseline
      )
    end

    def rain_baseline
      start_time = @date.in_time_zone("America/Los_Angeles").beginning_of_day
      WeatherMeasurement.where(reading_date_time: ...start_time)
                       .order(reading_date_time: :desc)
                       .first
    end

    # Hourly rows for this day were built from whatever the counter did inside
    # each hour. Recompute them with the full day so a later correction removes
    # rain that the station's counter no longer claims.
    def sync_hourly_rain(report)
      return if measurements.empty?

      amounts = rain_attribution.hourly_mm
      report.entries.hourly.where(day: @date.day).find_each do |entry|
        entry.update!(rain: amounts[entry.hour] || 0.0)
      end
    end

    def partial_day?
      measurements.count < (EXPECTED_MEASUREMENTS_PER_DAY * 0.8)
    end

    def format_time(datetime)
      return nil if datetime.nil?
      datetime.in_time_zone("America/Los_Angeles").strftime("%H:%M")
    end
  end
end
