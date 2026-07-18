# frozen_string_literal: true

module Iss
  # Two-line (or three-line with name) NORAD TLE parsed into orbital elements
  # for SGP4 propagation.
  class Tle
    DEG2RAD = Math::PI / 180.0
    XPDOTP = 1440.0 / (2.0 * Math::PI)

    attr_reader :name, :satnum, :epoch, :mean_motion, :eccentricity,
                :inclination_deg, :raan_deg, :argp_deg, :mean_anomaly_deg,
                :bstar, :ndot, :nddot

    # Parsed SGP4-ready values (radians / canonical units).
    attr_reader :epoch_days_since_1950, :inclination_rad, :raan_rad, :argp_rad,
                :mean_anomaly_rad, :mean_motion_rad_per_min,
                :ndot_sgp4, :nddot_sgp4

    class ParseError < StandardError; end

    def self.parse(text)
      lines = text.to_s.lines.map(&:strip).reject(&:empty?)
      raise ParseError, "TLE must have at least two lines" if lines.size < 2

      name = nil
      if lines.first.start_with?("1 ")
        line1 = lines[0]
        line2 = lines[1]
      else
        name = lines[0]
        line1 = lines[1]
        line2 = lines[2]
        raise ParseError, "TLE must have two element lines" if line2.nil?
      end

      new(name: name, line1: line1, line2: line2)
    end

    def initialize(name:, line1:, line2:)
      @name = name
      parse_lines!(line1, line2)
    end

    private

    def parse_lines!(line1, line2)
      validate_line1!(line1)
      validate_line2!(line2)

      @satnum = line1[2, 5].strip
      raise ParseError, "Object numbers in lines 1 and 2 do not match" unless @satnum == line2[2, 5].strip

      two_digit_year = line1[18, 2].to_i
      year = two_digit_year < 57 ? two_digit_year + 2000 : two_digit_year + 1900
      day_of_year = line1[20, 12].to_f

      @ndot = line1[33, 10].to_f
      nddot_mantissa = line1[44] + "." + line1[45, 5]
      nddot_exp = line1[50, 2].to_i
      @nddot = nddot_mantissa.to_f * (10**nddot_exp)

      bstar_mantissa = line1[53] + "." + line1[54, 5]
      bstar_exp = line1[59, 2].to_i
      @bstar = bstar_mantissa.to_f * (10**bstar_exp)

      @inclination_deg = line2[8, 8].to_f
      @raan_deg = line2[17, 8].to_f
      @eccentricity = ("0." + line2[26, 7].tr(" ", "0")).to_f
      @argp_deg = line2[34, 8].to_f
      @mean_anomaly_deg = line2[43, 8].to_f
      @mean_motion = line2[52, 11].to_f

      @epoch = epoch_time_utc(year, day_of_year)
      @epoch_days_since_1950 = julian_date(@epoch) - 2_433_281.5

      @inclination_rad = @inclination_deg * DEG2RAD
      @raan_rad = @raan_deg * DEG2RAD
      @argp_rad = @argp_deg * DEG2RAD
      @mean_anomaly_rad = @mean_anomaly_deg * DEG2RAD
      @mean_motion_rad_per_min = @mean_motion / XPDOTP

      # twoline2rv unit conversions for SGP4 init (ndot/nddot remain TLE units above).
      @ndot_sgp4 = @ndot / (XPDOTP * 1440.0)
      @nddot_sgp4 = @nddot / (XPDOTP * 1440.0 * 1440.0)
    end

    def validate_line1!(line)
      return if line.length >= 64 &&
                line.start_with?("1 ") &&
                line[8] == " " &&
                line[23] == "." &&
                line[32] == " " &&
                line[34] == "." &&
                line[43] == " " &&
                line[52] == " " &&
                line[61] == " " &&
                line[63] == " "

      raise ParseError, "Line 1 is not a valid TLE format"
    end

    def validate_line2!(line)
      return if line.length >= 68 &&
                line.start_with?("2 ") &&
                line[7] == " " &&
                line[11] == "." &&
                line[16] == " " &&
                line[20] == "." &&
                line[25] == " " &&
                line[33] == " " &&
                line[37] == "." &&
                line[42] == " " &&
                line[46] == "." &&
                line[51] == " "

      raise ParseError, "Line 2 is not a valid TLE format"
    end

    def epoch_time_utc(year, day_of_year)
      day_whole = day_of_year.floor
      day_fraction = day_of_year - day_whole
      seconds = day_fraction * 86_400.0
      Time.utc(year, 1, 1) + ((day_whole - 1) * 86_400.0) + seconds
    end

    def julian_date(time)
      y = time.utc.year
      m = time.utc.month
      d = time.utc.day
      hr = time.utc.hour
      minute = time.utc.min
      sec = time.utc.sec + time.utc.subsec

      (
        367.0 * y -
        7.0 * (y + ((m + 9.0) / 12.0).floor) / 4.0 +
        (275.0 * m / 9.0).floor +
        d + 1_721_013.5 +
        (((sec / 60.0) + minute) / 60.0 + hr) / 24.0
      )
    end
  end
end
