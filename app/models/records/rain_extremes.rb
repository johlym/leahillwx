module Records
  class RainExtremes
    def initialize(record:, measurements:, scope:, year:)
      @record = record
      @measurements = measurements
      @scope = scope
      @year = year
    end

    def calculate
      highest_daily_rain
      highest_rain_rate
      wettest_month
      consecutive_rain_days
    end

    private

    def highest_daily_rain
      highest = report_entries_scope
        .where.not(rain: nil)
        .order(rain: :desc)
        .limit(1)
        .first

      if highest
        @record.highest_daily_rain = highest.rain
        @record.highest_daily_rain_date = Date.new(highest.report.year, highest.report.month, highest.day)
      end
    end

    def highest_rain_rate
      highest_rate = @measurements.select(:rain_rate, :reading_date_time).order(rain_rate: :desc).limit(1).first
      @record.highest_rain_rate = highest_rate&.rain_rate
      @record.highest_rain_rate_at = highest_rate&.reading_date_time
    end

    def wettest_month
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
    end

    def consecutive_rain_days
      result = find_consecutive_rain_days

      if result[:wet]
        @record.consecutive_rain_days = result[:wet][:days]
        @record.consecutive_rain_start_date = result[:wet][:start_date]
      end

      if result[:dry]
        @record.consecutive_dry_days = result[:dry][:days]
        @record.consecutive_dry_start_date = result[:dry][:start_date]
      end
    end

    def find_consecutive_rain_days
      longest_wet = { days: 0, start_date: nil }
      longest_dry = { days: 0, start_date: nil }
      current_wet = { days: 0, start_date: nil }
      current_dry = { days: 0, start_date: nil }

      daily_data = ReportEntry.daily.joins(:report)
        .then { |q| @scope == "yearly" && @year ? q.where(reports: { year: @year }) : q }
        .order("reports.year ASC, reports.month ASC, report_entries.day ASC")
        .pluck(Arel.sql("CAST(reports.year || '-' || LPAD(reports.month::text, 2, '0') || '-' || LPAD(report_entries.day::text, 2, '0') AS DATE)"), :rain)

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

    def report_entries_scope
      base = ReportEntry.daily
      if @scope == "yearly" && @year
        base.joins(:report).where(reports: { year: @year })
      else
        base
      end
    end
  end
end
