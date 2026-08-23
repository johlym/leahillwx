module WeatherData
  class HourlyAggregator
    include WeatherUnitConversions
    include WindVectorAveraging

    EXPECTED_MEASUREMENTS_PER_HOUR = 60

    attr_reader :datetime, :measurements

    def initialize(datetime)
      @datetime = datetime.is_a?(Time) ? datetime : Time.parse(datetime.to_s)
      @measurements = fetch_measurements
    end

    def aggregate
      report = find_or_create_report
      entry = create_or_update_entry(report)

      entry
    end

    private

    def fetch_measurements
      start_time = @datetime.beginning_of_hour
      end_time = @datetime.end_of_hour

      WeatherMeasurement.where(reading_date_time: start_time..end_time)
                       .order(:reading_date_time)
    end

    def find_or_create_report
      Report.find_or_create_by!(year: @datetime.year, month: @datetime.month)
    end

    def create_or_update_entry(report)
      entry = report.entries.find_or_initialize_by(day: @datetime.day, hour: @datetime.hour)

      if measurements.empty?
        entry.assign_attributes(no_data_attributes)
      else
        entry.assign_attributes(calculate_hourly_stats)
        entry.partial_period = is_partial_hour?
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

    def calculate_hourly_stats
      temps_c = measurements.map(&:temperature)
      mean_temp_c = temps_c.sum / temps_c.size

      high_measurement = measurements.max_by(&:temperature)
      low_measurement = measurements.min_by(&:temperature)
      gust_measurement = measurements.max_by(&:gust_speed)
      high_pressure_measurement = measurements.max_by(&:barometer_rel)
      low_pressure_measurement = measurements.min_by(&:barometer_rel)

      wind_dir_degrees = self.class.calculate_dominant_wind_direction(measurements)
      wind_dir_compass = degrees_to_compass(wind_dir_degrees)

      wind_speeds_mps = measurements.map(&:wind_speed)
      avg_wind_speed_mps = wind_speeds_mps.sum / wind_speeds_mps.size

      pressures = measurements.map(&:barometer_rel)
      mean_pressure = pressures.sum / pressures.size

      # rain_day is a cumulative counter, so calculate the difference between max and min for this hour
      max_rain = measurements.maximum(:rain_day) || 0.0
      min_rain = measurements.minimum(:rain_day) || 0.0
      total_rain_mm = max_rain - min_rain

      # Convert mean temp to Fahrenheit for degree day calculations
      mean_temp_f = celsius_to_fahrenheit(mean_temp_c)

      {
        mean_temp: mean_temp_c,
        high_temp: high_measurement.temperature,
        high_temp_time: format_time(high_measurement.reading_date_time),
        low_temp: low_measurement.temperature,
        low_temp_time: format_time(low_measurement.reading_date_time),
        heat_degree_days: calculate_heat_degree_days(mean_temp_f) / 24.0, # Proportional to hour
        cool_degree_days: calculate_cool_degree_days(mean_temp_f) / 24.0, # Proportional to hour
        rain: total_rain_mm,
        avg_wind_speed: avg_wind_speed_mps,
        high_wind_speed: gust_measurement.gust_speed,
        high_wind_time: format_time(gust_measurement.reading_date_time),
        wind_dir: wind_dir_degrees,
        wind_dir_compass: wind_dir_compass,
        mean_pressure: mean_pressure,
        high_pressure: high_pressure_measurement.barometer_rel,
        high_pressure_time: format_time(high_pressure_measurement.reading_date_time),
        low_pressure: low_pressure_measurement.barometer_rel,
        low_pressure_time: format_time(low_pressure_measurement.reading_date_time)
      }
    end

    def is_partial_hour?
      measurements.count < (EXPECTED_MEASUREMENTS_PER_HOUR * 0.8)
    end

    def format_time(datetime)
      return nil if datetime.nil?
      datetime.strftime("%H:%M")
    end
  end
end
