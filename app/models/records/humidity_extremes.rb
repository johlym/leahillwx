module Records
  class HumidityExtremes
    def initialize(record:, measurements:, scope:, year:)
      @record = record
      @measurements = measurements
      @scope = scope
      @year = year
    end

    def calculate
      highest_and_lowest_humidity
      dew_point_extremes
    end

    private

    def highest_and_lowest_humidity
      highest = @measurements.select(:humidity, :reading_date_time).order(humidity: :desc).limit(1).first
      @record.highest_humidity = highest&.humidity
      @record.highest_humidity_at = highest&.reading_date_time

      lowest = @measurements.select(:humidity, :reading_date_time).order(humidity: :asc).limit(1).first
      @record.lowest_humidity = lowest&.humidity
      @record.lowest_humidity_at = lowest&.reading_date_time
    end

    def dew_point_extremes
      highest_dew = @measurements
        .select(:temperature, :humidity, :reading_date_time)
        .order(Arel.sql("temperature - ((100 - humidity) / 5.0)"))
        .reverse_order
        .limit(1)
        .first
      if highest_dew
        @record.highest_dew_point = highest_dew.dew_point
        @record.highest_dew_point_at = highest_dew.reading_date_time
      end

      lowest_dew = @measurements
        .select(:temperature, :humidity, :reading_date_time)
        .order(Arel.sql("temperature - ((100 - humidity) / 5.0)"))
        .limit(1)
        .first
      if lowest_dew
        @record.lowest_dew_point = lowest_dew.dew_point
        @record.lowest_dew_point_at = lowest_dew.reading_date_time
      end
    end
  end
end
