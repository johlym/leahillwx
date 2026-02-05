module Celestial
  class EphemerisService
    def self.generate(body, datestamp = {})
      new(body, datestamp).generate
    end

    def initialize(body, datestamp = {})
      @body = body
      @year = datestamp[:year]&.to_i || Time.current.year
      @month = datestamp[:month]&.to_i || Time.current.month
      @day = datestamp[:day]&.to_i || Time.current.day
    end

    def generate
      validate_date!
      time = Time.now
      data = generate_ephemeris_data
      time = Time.now - time
      Rails.logger.info "Ephemeris generation for #{@year}-#{@month}-#{@day} took #{time} seconds"
      data
    rescue ArgumentError => e
      { error: "Invalid date: #{@year}-#{@month}-#{@day}" }
    rescue Ephem::OutOfRangeError => e
      Rails.logger.error "Date outside ephemeris coverage: #{@year}-#{@month}-#{@day}"
      { error: "Date outside ephemeris coverage (1990-2050)" }
    rescue => e
      Rails.logger.error "Failed to generate ephemeris: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      { error: "Failed to generate ephemeris data" }
    end

    private

    def validate_date!
      Date.new(@year, @month, @day)
    end

    def generate_ephemeris_data
      generator = EphemerisPolynomialGenerator.new
      generator.generate_daily_ephemeris(@body, @year, @month, @day)
    end
  end
end
