module Records
  class TemperatureExtremes
    def initialize(record:, measurements:, scope:, year:)
      @record = record
      @measurements = measurements
      @scope = scope
      @year = year
    end

    def calculate
      highest_and_lowest_temp
      apparent_temp_extremes
      heat_index_and_wind_chill
      daily_temp_ranges
    end

    private

    def highest_and_lowest_temp
      highest = @measurements.select(:temperature, :reading_date_time).order(temperature: :desc).limit(1).first
      @record.highest_temp = highest&.temperature
      @record.highest_temp_at = highest&.reading_date_time

      lowest = @measurements.select(:temperature, :reading_date_time).order(temperature: :asc).limit(1).first
      @record.lowest_temp = lowest&.temperature
      @record.lowest_temp_at = lowest&.reading_date_time
    end

    def apparent_temp_extremes
      highest_apparent = @measurements
        .select(:temperature, :humidity, :wind_speed, :reading_date_time)
        .order(Arel.sql("temperature - ((100 - humidity) / 5.0)"))
        .reverse_order
        .limit(1)
        .first
      if highest_apparent
        @record.highest_apparent_temp = highest_apparent.feels_like
        @record.highest_apparent_temp_at = highest_apparent.reading_date_time
      end

      lowest_apparent = @measurements
        .select(:temperature, :humidity, :wind_speed, :reading_date_time)
        .order(Arel.sql("temperature - ((100 - humidity) / 5.0)"))
        .limit(1)
        .first
      if lowest_apparent
        @record.lowest_apparent_temp = lowest_apparent.feels_like
        @record.lowest_apparent_temp_at = lowest_apparent.reading_date_time
      end
    end

    def heat_index_and_wind_chill
      highest_heat_index = @measurements
        .select(:temperature, :humidity, :wind_speed, :reading_date_time)
        .where("temperature > 27")
        .where("humidity >= 40")
        .order(Arel.sql("temperature - ((100 - humidity) / 5.0)"))
        .reverse_order
        .limit(1)
        .first
      if highest_heat_index
        @record.highest_heat_index = highest_heat_index.feels_like
        @record.highest_heat_index_at = highest_heat_index.reading_date_time
      end

      lowest_wind_chill = @measurements
        .select(:temperature, :humidity, :wind_speed, :reading_date_time)
        .where("temperature < 10")
        .where("wind_speed > 1.34")
        .order(Arel.sql("temperature - ((100 - humidity) / 5.0)"))
        .limit(1)
        .first
      if lowest_wind_chill
        @record.lowest_wind_chill = lowest_wind_chill.feels_like
        @record.lowest_wind_chill_at = lowest_wind_chill.reading_date_time
      end
    end

    def daily_temp_ranges
      largest_range = report_entries_scope
        .where.not(high_temp: nil, low_temp: nil)
        .select("report_entries.*, (high_temp - low_temp) as temp_range")
        .order("temp_range DESC")
        .limit(1)
        .first

      if largest_range
        @record.largest_temp_range = largest_range.high_temp - largest_range.low_temp
        @record.largest_temp_range_date = Date.new(largest_range.report.year, largest_range.report.month, largest_range.day)
      end

      smallest_range = report_entries_scope
        .where.not(high_temp: nil, low_temp: nil)
        .select("report_entries.*, (high_temp - low_temp) as temp_range")
        .order("temp_range ASC")
        .limit(1)
        .first

      if smallest_range
        @record.smallest_temp_range = smallest_range.high_temp - smallest_range.low_temp
        @record.smallest_temp_range_date = Date.new(smallest_range.report.year, smallest_range.report.month, smallest_range.day)
      end
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
