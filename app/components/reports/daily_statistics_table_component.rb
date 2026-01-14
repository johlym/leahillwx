module Reports
  class DailyStatisticsTableComponent < ViewComponent::Base
    def initialize(report:, has_partial_days:)
      @report = report
      @has_partial_days = has_partial_days
    end

    def daily_data
      @daily_data ||= (1..report.days_in_month).map do |day|
        entry = entries.find { |e| e.day == day }

        DailyDataRow.new(
          day: day,
          entry: entry,
          is_future_day: future_day?(day),
          is_current_day: current_day?(day),
          is_max_mean_temp: entry&.mean_temp&.to_fahrenheit == max_values[:mean_temp],
          is_max_high_temp: entry&.high_temp&.to_fahrenheit == max_values[:high_temp],
          is_max_low_temp: entry&.low_temp&.to_fahrenheit == max_values[:low_temp],
          is_max_heat_dd: entry&.heat_degree_days == max_values[:heat_dd],
          is_max_cool_dd: entry&.cool_degree_days == max_values[:cool_dd],
          is_max_rain: entry&.rain == max_values[:rain],
          is_max_avg_wind: entry&.avg_wind_speed == max_values[:avg_wind],
          is_max_high_wind: entry&.high_wind_speed == max_values[:high_wind]
        )
      end.reject(&:is_future_day)
    end

    private

    attr_reader :report

    def entries
      @entries ||= report.entries.ordered
    end

    def entries_with_data
      @entries_with_data ||= entries.select(&:has_data?)
    end

    def max_values
      @max_values ||= {
        mean_temp: entries_with_data.map { |e| e.mean_temp&.to_fahrenheit }.compact.max,
        high_temp: entries_with_data.map { |e| e.high_temp&.to_fahrenheit }.compact.max,
        low_temp: entries_with_data.map { |e| e.low_temp&.to_fahrenheit }.compact.max,
        heat_dd: entries_with_data.map(&:heat_degree_days).compact.max,
        cool_dd: entries_with_data.map(&:cool_degree_days).compact.max,
        rain: entries_with_data.map(&:rain).compact.max,
        avg_wind: entries_with_data.map(&:avg_wind_speed).compact.max,
        high_wind: entries_with_data.map(&:high_wind_speed).compact.max
      }
    end

    def future_day?(day)
      day > Date.today.day &&
      report.year == Date.today.year &&
      report.month == Date.today.month
    end

    def current_day?(day)
      day == Date.today.day &&
      report.year == Date.today.year &&
      report.month == Date.today.month
    end

    class DailyDataRow
      attr_reader :day, :entry, :is_future_day, :is_current_day,
                  :is_max_mean_temp, :is_max_high_temp, :is_max_low_temp,
                  :is_max_heat_dd, :is_max_cool_dd, :is_max_rain,
                  :is_max_avg_wind, :is_max_high_wind

      def initialize(day:, entry:, is_future_day:, is_current_day:,
                     is_max_mean_temp:, is_max_high_temp:, is_max_low_temp:,
                     is_max_heat_dd:, is_max_cool_dd:, is_max_rain:,
                     is_max_avg_wind:, is_max_high_wind:)
        @day = day
        @entry = entry
        @is_future_day = is_future_day
        @is_current_day = is_current_day
        @is_max_mean_temp = is_max_mean_temp
        @is_max_high_temp = is_max_high_temp
        @is_max_low_temp = is_max_low_temp
        @is_max_heat_dd = is_max_heat_dd
        @is_max_cool_dd = is_max_cool_dd
        @is_max_rain = is_max_rain
        @is_max_avg_wind = is_max_avg_wind
        @is_max_high_wind = is_max_high_wind
      end

      def has_data?
        entry&.has_data?
      end

      def partial_day?
        entry&.partial_day
      end
    end
  end
end
