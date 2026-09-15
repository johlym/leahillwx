module Records
  class MeasurementScope
    attr_reader :scope, :year

    PACIFIC = ActiveSupport::TimeZone["America/Los_Angeles"]

    def initialize(scope:, year: nil)
      @scope = scope
      @year = year
    end

    def resolve
      base = WeatherMeasurement.all
      if scope == "yearly" && year
        start_at, end_at = pacific_year_bounds(year)
        base.where(reading_date_time: start_at...end_at)
      else
        base
      end
    end

    private

    # Match DailyAggregator: calendar bounds in America/Los_Angeles, not DB session TZ.
    def pacific_year_bounds(year)
      start_at = PACIFIC.local(year, 1, 1).beginning_of_day
      today = Time.current.in_time_zone(PACIFIC).to_date
      end_at =
        if year == today.year
          PACIFIC.local(today.year, today.month, today.day).beginning_of_day
        else
          PACIFIC.local(year, 12, 31).end_of_day + 1.second
        end
      [start_at, end_at]
    end
  end
end
