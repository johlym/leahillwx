module WeatherData
  class MonthlyStatsCalculator
    include WeatherUnitConversions
    include WindVectorAveraging

    attr_reader :report

    def initialize(report)
      @report = report
    end

    def calculate
      entries = report.entries.daily.with_data.ordered

      return report if entries.empty?

      report.update!(
        month_mean_temp: calculate_monthly_mean_temp(entries),
        month_high_temp: calculate_month_high_temp(entries),
        month_high_temp_day: find_high_temp_day(entries),
        month_low_temp: calculate_month_low_temp(entries),
        month_low_temp_day: find_low_temp_day(entries),
        total_heat_degree_days: calculate_total_heat_degree_days(entries),
        total_cool_degree_days: calculate_total_cool_degree_days(entries),
        total_rain: calculate_total_rain(entries),
        avg_wind_speed: calculate_avg_wind_speed(entries),
        month_high_wind_speed: calculate_month_high_wind(entries),
        month_high_wind_day: find_high_wind_day(entries),
        dominant_wind_dir: calculate_monthly_dominant_wind(entries),
        dominant_wind_dir_compass: degrees_to_compass(calculate_monthly_dominant_wind(entries)),
        month_mean_pressure: calculate_monthly_mean_pressure(entries),
        month_high_pressure: calculate_month_high_pressure(entries),
        month_high_pressure_day: find_high_pressure_day(entries),
        month_low_pressure: calculate_month_low_pressure(entries),
        month_low_pressure_day: find_low_pressure_day(entries)
      )

      report
    end

    private

    def calculate_monthly_mean_temp(entries)
      temps = entries.map(&:mean_temp).compact
      return nil if temps.empty?
      temps.sum / temps.size
    end

    def calculate_month_high_temp(entries)
      entries.map(&:high_temp).compact.max
    end

    def find_high_temp_day(entries)
      entry = entries.max_by { |e| e.high_temp || -Float::INFINITY }
      entry&.day
    end

    def calculate_month_low_temp(entries)
      entries.map(&:low_temp).compact.min
    end

    def find_low_temp_day(entries)
      entry = entries.min_by { |e| e.low_temp || Float::INFINITY }
      entry&.day
    end

    def calculate_total_heat_degree_days(entries)
      entries.map(&:heat_degree_days).compact.sum
    end

    def calculate_total_cool_degree_days(entries)
      entries.map(&:cool_degree_days).compact.sum
    end

    def calculate_total_rain(entries)
      entries.map(&:rain).compact.sum
    end

    def calculate_avg_wind_speed(entries)
      speeds = entries.map(&:avg_wind_speed).compact
      return nil if speeds.empty?
      speeds.sum / speeds.size
    end

    def calculate_month_high_wind(entries)
      entries.map(&:high_wind_speed).compact.max
    end

    def find_high_wind_day(entries)
      entry = entries.max_by { |e| e.high_wind_speed || -Float::INFINITY }
      entry&.day
    end

    def calculate_monthly_mean_pressure(entries)
      pressures = entries.map(&:mean_pressure).compact
      return nil if pressures.empty?
      pressures.sum / pressures.size
    end

    def calculate_month_high_pressure(entries)
      entries.map(&:high_pressure).compact.max
    end

    def find_high_pressure_day(entries)
      entry = entries.max_by { |e| e.high_pressure || -Float::INFINITY }
      entry&.day
    end

    def calculate_month_low_pressure(entries)
      entries.map(&:low_pressure).compact.min
    end

    def find_low_pressure_day(entries)
      entry = entries.min_by { |e| e.low_pressure || Float::INFINITY }
      entry&.day
    end

    def calculate_monthly_dominant_wind(entries)
      wind_dirs = entries.map(&:wind_dir).compact
      wind_speeds = entries.map(&:avg_wind_speed).compact

      return nil if wind_dirs.empty? || wind_speeds.empty?

      u_sum = 0.0
      v_sum = 0.0

      entries.each do |entry|
        next if entry.wind_dir.nil? || entry.avg_wind_speed.nil?

        wind_speed = entry.avg_wind_speed
        wind_dir = entry.wind_dir

        theta_rad = wind_dir * Math::PI / 180.0
        u_sum += wind_speed * Math.sin(theta_rad)
        v_sum += wind_speed * Math.cos(theta_rad)
      end

      return nil if u_sum.zero? && v_sum.zero?

      angle_rad = Math.atan2(u_sum, v_sum)
      angle_deg = angle_rad * 180.0 / Math::PI
      angle_deg += 360.0 if angle_deg < 0

      angle_deg.round
    end
  end
end
