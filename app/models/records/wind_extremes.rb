module Records
  class WindExtremes
    def initialize(record:, measurements:, scope:, year:)
      @record = record
      @measurements = measurements
      @scope = scope
      @year = year
    end

    def calculate
      strongest_gust
      highest_wind_run
    end

    private

    def strongest_gust
      strongest = @measurements.select(:gust_speed, :reading_date_time).order(gust_speed: :desc).limit(1).first
      @record.strongest_gust = strongest&.gust_speed
      @record.strongest_gust_at = strongest&.reading_date_time
    end

    def highest_wind_run
      highest_run = @measurements
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
  end
end
