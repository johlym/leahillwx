module Records
  class MeasurementScope
    attr_reader :scope, :year

    def initialize(scope:, year: nil)
      @scope = scope
      @year = year
    end

    def resolve
      base = WeatherMeasurement.all
      if scope == "yearly" && year
        query = base.where("EXTRACT(YEAR FROM reading_date_time) = ?", year)
        if year == Time.current.year
          query = query.where("DATE(reading_date_time) < ?", Time.current.in_time_zone("America/Los_Angeles").to_date)
        end
        query
      else
        base
      end
    end
  end
end
