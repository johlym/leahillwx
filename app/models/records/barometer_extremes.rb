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
      highest = @measurements.select(:barometer_rel, :reading_date_time).order(barometer_rel: :desc).limit(1).first
      @record.highest_pressure = highest&.barometer_rel
      @record.highest_pressure_at = highest&.reading_date_time

      lowest = @measurements.select(:barometer_rel, :reading_date_time).order(barometer_rel: :asc).limit(1).first
      @record.lowest_pressure = lowest&.barometer_rel
      @record.lowest_pressure_at = lowest&.reading_date_time
    end

    def largest_pressure_swing
      largest_swing = @measurements
        .select("DATE(reading_date_time) as date, MAX(barometer_rel) - MIN(barometer_rel) as pressure_swing")
        .group("DATE(reading_date_time)")
        .order("pressure_swing DESC")
        .limit(1)
        .first

      if largest_swing
        @record.largest_pressure_swing = largest_swing.pressure_swing
        @record.largest_pressure_swing_date = largest_swing.date
      end
    end
  end
end
