module Records
  class SolarExtremes
    def initialize(record:, measurements:, scope:, year:)
      @record = record
      @measurements = measurements
      @scope = scope
      @year = year
    end

    def calculate
      highest = @measurements.select(:light, :reading_date_time).order(light: :desc).limit(1).first
      @record.highest_solar = highest&.light
      @record.highest_solar_at = highest&.reading_date_time
    end
  end
end
