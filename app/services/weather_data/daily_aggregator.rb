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
      entry = report.entries.find_or_initialize_by(day: @date.day)

      if measurements.empty?
        entry.assign_attributes(no_data_attributes)
      else
        entry.assign_attributes(calculate_daily_stats)
        entry.partial_day = partial_day?
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
        partial_day: false
      }
    end

    def calculate_daily_stats
      temps_c = measurements.map(&:temperature)
      mean_temp_c = temps_c.sum / temps_c.size

      high_measurement = measurements.max_by(&:temperature)
      low_measurement = measurements.min_by(&:temperature)
      gust_measurement = measurements.max_by(&:gust_speed)

      wind_dir_degrees = self.class.calculate_dominant_wind_direction(measurements)
      wind_dir_compass = degrees_to_compass(wind_dir_degrees)

      wind_speeds_mph = measurements.map { |m| mps_to_mph(m.wind_speed) }
      avg_wind_speed_mph = wind_speeds_mph.sum / wind_speeds_mph.size

      final_rain = measurements.last&.rain_day || 0.0
      rain_inches = mm_to_inches(final_rain)

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
        rain: rain_inches,
        avg_wind_speed: avg_wind_speed_mph,
        high_wind_speed: mps_to_mph(gust_measurement.gust_speed),
        high_wind_time: format_time(gust_measurement.reading_date_time),
        wind_dir: wind_dir_degrees,
        wind_dir_compass: wind_dir_compass
      }
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
