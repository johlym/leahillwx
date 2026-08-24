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
      highest = @measurements
        .select(:reading_date_time, Arel.sql("#{qff_sql} AS qff"))
        .order(Arel.sql("#{qff_sql} DESC"))
        .limit(1)
        .first
      @record.highest_pressure = highest&.qff
      @record.highest_pressure_at = highest&.reading_date_time

      lowest = @measurements
        .select(:reading_date_time, Arel.sql("#{qff_sql} AS qff"))
        .order(Arel.sql("#{qff_sql} ASC"))
        .limit(1)
        .first
      @record.lowest_pressure = lowest&.qff
      @record.lowest_pressure_at = lowest&.reading_date_time
    end

    def largest_pressure_swing
      largest_swing = @measurements
        .select("DATE(reading_date_time) as date, MAX(#{qff_sql}) as max_qff, MIN(#{qff_sql}) as min_qff")
        .group("DATE(reading_date_time)")
        .order(Arel.sql("MAX(#{qff_sql}) - MIN(#{qff_sql}) DESC"))
        .limit(1)
        .first

      if largest_swing&.max_qff && largest_swing.min_qff
        @record.largest_pressure_swing = largest_swing.max_qff - largest_swing.min_qff
        @record.largest_pressure_swing_date = largest_swing.date
      end
    end

    def qff_sql
      SeaLevelPressure.qff_sql
    end
  end
end
