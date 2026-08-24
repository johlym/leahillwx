module Records
  class BarometerExtremes
    def initialize(record:, measurements:, scope:, year:)
      @record = record
      @measurements = measurements
      @scope = scope
      @year = year
    end

    def calculate
      highest_and_lowest_pressure
      largest_pressure_swing
    end

    private

    def highest_and_lowest_pressure
      highest = @measurements.select(:barometer_abs, :reading_date_time).order(barometer_abs: :desc).limit(1).first
      @record.highest_pressure = slp(highest&.barometer_abs)
      @record.highest_pressure_at = highest&.reading_date_time

      lowest = @measurements.select(:barometer_abs, :reading_date_time).order(barometer_abs: :asc).limit(1).first
      @record.lowest_pressure = slp(lowest&.barometer_abs)
      @record.lowest_pressure_at = lowest&.reading_date_time
    end

    def largest_pressure_swing
      largest_swing = @measurements
        .select("DATE(reading_date_time) as date, MAX(barometer_abs) as max_abs, MIN(barometer_abs) as min_abs")
        .group("DATE(reading_date_time)")
        .order(Arel.sql("MAX(barometer_abs) - MIN(barometer_abs) DESC"))
        .limit(1)
        .first

      if largest_swing&.max_abs && largest_swing.min_abs
        @record.largest_pressure_swing = slp(largest_swing.max_abs) - slp(largest_swing.min_abs)
        @record.largest_pressure_swing_date = largest_swing.date
      end
    end

    def slp(station_hpa)
      SeaLevelPressure.hpa(station_hpa)
    end
  end
end
