module Almanac
  # Cross-Validation Service for Astronomical Position Calculations
  #
  # Purpose: Compare real-time analytical positions against ephemeris-based
  # authoritative positions to ensure quality and detect drift.
  #
  # IMPORTANT: Validation is based on OBSERVABLE coordinates (altitude/azimuth).
  # RA/Dec differences are logged for information only and do NOT cause failures.
  #
  # Analytical RA/Dec are:
  # - True-of-date (not J2000/ICRF)
  # - Topocentric (observer position applied)
  # - Not directly comparable to ephemeris RA/Dec without frame transforms
  #
  # Per Specification:
  # - Sun altitude difference > 0.1° → fail
  # - Moon altitude difference > 0.25° → fail
  # - Moon horizontal angular separation > 2.0° → fail
  # - RA/Dec differences are informational only
  # - Azimuth differences are informational only (unstable metric)
  # - Offline ephemeris remains authoritative
  #
  # IMPORTANT: Moon validation compares topocentric analytical vs geocentric ephemeris.
  # This creates an expected ~1-2° parallax offset in angular separation.
  # This is correct behavior, not an error.
  class PositionValidator
    # Tolerance thresholds for OBSERVABLE coordinates (degrees)
    SUN_ALTITUDE_TOLERANCE_DEG = 0.1
    MOON_ALTITUDE_TOLERANCE_DEG = 0.25
    MOON_ANGULAR_SEPARATION_TOLERANCE_DEG = 2.0  # Accounts for topocentric vs geocentric parallax

    DEG2RAD = Math::PI / 180.0
    RAD2DEG = 180.0 / Math::PI

    def initialize(lat:, lon:, elevation: 0.0)
      @lat = lat
      @lon = lon
      @elevation = elevation
    end

    # Validate sun position at a specific time
    # Returns: { valid: Boolean, differences: Hash, warnings: Array, info: Array }
    def validate_sun_position(datetime)
      # Get analytical position (real-time path)
      analytical_service = ApproximateCelestialPosition.new(
        datetime: datetime,
        lat: @lat,
        lon: @lon,
        elevation: @elevation
      )
      analytical_pos = analytical_service.sun_position

      # Get ephemeris position (authoritative path)
      ephemeris_service = EphemGenerator.new
      jd = ephemeris_service.send(:datetime_to_julian_date, datetime)
      ephemeris_pos = ephemeris_service.send(:calculate_sun_position_bsp, jd)

      # Calculate differences
      differences = calculate_position_differences(analytical_pos, ephemeris_pos)

      # Primary validation: OBSERVABLE coordinates only
      warnings = []
      if differences[:altitude_deg] > SUN_ALTITUDE_TOLERANCE_DEG
        warnings << "Sun altitude difference (#{differences[:altitude_deg].round(3)}°) exceeds tolerance (#{SUN_ALTITUDE_TOLERANCE_DEG}°)"
      end

      # Informational only: RA/Dec differences (do NOT fail on these)
      info = []
      info << "RA diff: #{differences[:ra_deg].round(3)}° (informational - frame mismatch expected)"
      info << "Dec diff: #{differences[:dec_deg].round(3)}° (informational - frame mismatch expected)"

      {
        valid: warnings.empty?,
        differences: differences,
        warnings: warnings,
        info: info,
        analytical: analytical_pos,
        ephemeris: ephemeris_pos
      }
    end

    # Validate moon position at a specific time
    # Returns: { valid: Boolean, differences: Hash, warnings: Array, info: Array }
    def validate_moon_position(datetime)
      # Get analytical position (real-time path)
      analytical_service = ApproximateCelestialPosition.new(
        datetime: datetime,
        lat: @lat,
        lon: @lon,
        elevation: @elevation
      )
      analytical_pos = analytical_service.moon_position

      # Get ephemeris position (authoritative path)
      ephemeris_service = EphemGenerator.new
      jd = ephemeris_service.send(:datetime_to_julian_date, datetime)
      ephemeris_pos = ephemeris_service.send(:calculate_moon_position_bsp, jd)

      # Calculate differences
      differences = calculate_position_differences(analytical_pos, ephemeris_pos)

      # Primary validation: OBSERVABLE coordinates only
      warnings = []
      if differences[:altitude_deg] > MOON_ALTITUDE_TOLERANCE_DEG
        warnings << "Moon altitude difference (#{differences[:altitude_deg].round(3)}°) exceeds tolerance (#{MOON_ALTITUDE_TOLERANCE_DEG}°)"
      end

      # Use horizontal angular separation (more stable than raw azimuth)
      ang_sep = horizontal_angular_separation(
        analytical_pos[:altitude_deg], analytical_pos[:azimuth_deg],
        ephemeris_pos[:altitude], ephemeris_pos[:azimuth]
      )
      if ang_sep > MOON_ANGULAR_SEPARATION_TOLERANCE_DEG
        warnings << "Moon horizontal angular separation (#{ang_sep.round(3)}°) exceeds tolerance (#{MOON_ANGULAR_SEPARATION_TOLERANCE_DEG}°)"
      end

      # Informational only: RA/Dec and azimuth differences (do NOT fail on these)
      info = []
      info << "RA diff: #{differences[:ra_deg].round(3)}° (informational - frame mismatch expected)"
      info << "Dec diff: #{differences[:dec_deg].round(3)}° (informational - frame mismatch expected)"
      info << "Az diff: #{differences[:azimuth_deg].round(3)}° (informational - unstable metric)"
      info << "Horizontal angular separation: #{ang_sep.round(3)}°"

      {
        valid: warnings.empty?,
        differences: differences,
        warnings: warnings,
        info: info,
        analytical: analytical_pos,
        ephemeris: ephemeris_pos
      }
    end

    # Run validation for both sun and moon at current time
    def validate_current_positions
      datetime = Time.current

      {
        timestamp: datetime,
        sun: validate_sun_position(datetime),
        moon: validate_moon_position(datetime)
      }
    end

    private

    def horizontal_angular_separation(alt1, az1, alt2, az2)
      # Calculate true angular distance between two points on celestial sphere
      # This is more stable than raw azimuth difference, especially at high altitudes
      alt1r = alt1 * DEG2RAD
      az1r  = az1  * DEG2RAD
      alt2r = alt2 * DEG2RAD
      az2r  = az2  * DEG2RAD

      Math.acos(
        Math.sin(alt1r) * Math.sin(alt2r) +
        Math.cos(alt1r) * Math.cos(alt2r) * Math.cos(az1r - az2r)
      ) * RAD2DEG
    end

    def calculate_position_differences(analytical, ephemeris)
      # Handle both hash key formats (symbols and strings)
      analytical = normalize_keys(analytical)
      ephemeris = normalize_keys(ephemeris)

      # Calculate angular differences
      ra_diff = angular_difference(analytical[:ra_deg], ephemeris[:ra_deg])
      dec_diff = (analytical[:dec_deg] - ephemeris[:dec_deg]).abs
      alt_diff = (analytical[:altitude_deg] - ephemeris[:altitude_deg]).abs
      az_diff = angular_difference(analytical[:azimuth_deg], ephemeris[:azimuth_deg])

      # Total position difference (Euclidean in RA/Dec space)
      total = Math.sqrt(ra_diff**2 + dec_diff**2)

      {
        ra_deg: ra_diff,
        dec_deg: dec_diff,
        altitude_deg: alt_diff,
        azimuth_deg: az_diff,
        total_deg: total
      }
    end

    def normalize_keys(hash)
      {
        ra_deg: hash[:ra_deg] || hash[:ra],
        dec_deg: hash[:dec_deg] || hash[:dec],
        altitude_deg: hash[:altitude_deg] || hash[:altitude],
        azimuth_deg: hash[:azimuth_deg] || hash[:azimuth]
      }
    end

    def angular_difference(angle1, angle2)
      # Calculate shortest angular distance, handling wraparound at 360°
      diff = (angle1 - angle2).abs
      diff = 360.0 - diff if diff > 180.0
      diff
    end
  end
end
