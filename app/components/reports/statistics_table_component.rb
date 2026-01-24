module Reports
  class StatisticsTableComponent < ViewComponent::Base
    include UnitConversions

    def initialize(report:, day: nil, period_type: :daily, has_partial_periods: false)
      @report = report
      @day = day
      @period_type = period_type
      @has_partial_periods = has_partial_periods
    end

    def period_data
      @period_data ||= periods.map do |period|
        entry = entries.find { |e| matches_period?(e, period) }

        PeriodDataRow.new(
          period: period,
          period_type: @period_type,
          entry: entry,
          is_future: future_period?(period),
          is_current: current_period?(period),
          is_max_mean_temp: entry&.mean_temp&.to_fahrenheit == max_values[:mean_temp],
          is_max_high_temp: entry&.high_temp&.to_fahrenheit == max_values[:high_temp],
          is_max_low_temp: entry&.low_temp&.to_fahrenheit == max_values[:low_temp],
          is_max_heat_dd: entry&.heat_degree_days == max_values[:heat_dd],
          is_max_cool_dd: entry&.cool_degree_days == max_values[:cool_dd],
          is_max_rain: entry&.rain == max_values[:rain],
          is_max_avg_wind: entry&.avg_wind_speed == max_values[:avg_wind],
          is_max_high_wind: entry&.high_wind_speed == max_values[:high_wind],
          report: @report
        )
      end.reject(&:is_future)
    end

    def daily?
      @period_type == :daily
    end

    def hourly?
      @period_type == :hourly
    end

    def period_label
      daily? ? "Day" : "Hour"
    end

    def partial_note
      period_label = daily? ? "day" : "hour"
      output = "An <i class=\"fa-regular fa-triangle-exclamation text-yellow-800\"></i> and a row in <strong>yellow</strong> indicates an incomplete set of measurements (less than 80% of the minimum measurements in a given #{period_label}."
      output.html_safe
    end

    private

    attr_reader :report

    def periods
      if daily?
        (1..report.days_in_month).to_a
      else
        (0..23).to_a
      end
    end

    def matches_period?(entry, period)
      if daily?
        entry.day == period && entry.hour.nil?
      else
        entry.day == @day && entry.hour == period
      end
    end

    def entries
      @entries ||= if daily?
        report.entries.daily.ordered
      else
        report.entries.hourly.for_day(@day).ordered
      end
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

    def future_period?(period)
      now = Time.current.in_time_zone("America/Los_Angeles")
      if daily?
        period > now.day &&
        report.year == now.year &&
        report.month == now.month
      else
        period > now.hour &&
        @day == now.day &&
        report.year == now.year &&
        report.month == now.month
      end
    end

    def current_period?(period)
      now = Time.current.in_time_zone("America/Los_Angeles")
      if daily?
        period == now.day &&
        report.year == now.year &&
        report.month == now.month
      else
        period == now.hour &&
        @day == now.day &&
        report.year == now.year &&
        report.month == now.month
      end
    end

    class PeriodDataRow
      attr_reader :period, :period_type, :entry, :is_future, :is_current,
                  :is_max_mean_temp, :is_max_high_temp, :is_max_low_temp,
                  :is_max_heat_dd, :is_max_cool_dd, :is_max_rain,
                  :is_max_avg_wind, :is_max_high_wind, :report

      def initialize(period:, period_type:, entry:, is_future:, is_current:,
                     is_max_mean_temp:, is_max_high_temp:, is_max_low_temp:,
                     is_max_heat_dd:, is_max_cool_dd:, is_max_rain:,
                     is_max_avg_wind:, is_max_high_wind:, report:)
        @period = period
        @period_type = period_type
        @entry = entry
        @is_future = is_future
        @is_current = is_current
        @is_max_mean_temp = is_max_mean_temp
        @is_max_high_temp = is_max_high_temp
        @is_max_low_temp = is_max_low_temp
        @is_max_heat_dd = is_max_heat_dd
        @is_max_cool_dd = is_max_cool_dd
        @is_max_rain = is_max_rain
        @is_max_avg_wind = is_max_avg_wind
        @is_max_high_wind = is_max_high_wind
        @report = report
      end

      def has_data?
        entry&.has_data?
      end

      def partial_period?
        entry&.partial_period
      end

      def day
        entry&.day || @period
      end
    end
  end
end
