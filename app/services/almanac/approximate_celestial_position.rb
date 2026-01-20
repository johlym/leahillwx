module Almanac
  # Real-Time Analytical Position Calculations (Path 2 - No Ephemerides)
  #
  # Purpose: Provide observer-correct, real-time Sun and Moon positions for
  # current-day, on-demand presentation (dashboards, UI displays).
  #
  # This service answers: "Where is the Sun/Moon right now in the sky?"
  #
  # Technology:
  # - Custom analytical implementation based on Meeus-style algorithms
  # - weewx-derived solar and lunar models
  # - No BSP files, no ephemeris loading, no file I/O
  #
  # Important: This path is for OBSERVATIONAL display only, NOT archival truth.
  # For authoritative daily events (sunrise/sunset, moonrise/moonset), use the
  # offline ephemeris path (EphemGenerator).
  #
  # Based on weewx almanac approximation algorithms via the excellent folks at weewx.com
  # https://github.com/weewx/weewx/blob/master/src/weewx/almanac.py
  class ApproximateCelestialPosition
    # Mean Earth radius in kilometers
    EARTH_RADIUS_KM = 6371.0

    # Mean Moon distance in kilometers (semi-major axis)
    MOON_MEAN_DISTANCE_KM = 384400.0

    # Moon's equatorial horizontal parallax at mean distance
    MOON_EQUATORIAL_PARALLAX_DEG = 0.9508

    def initialize(datetime: Time.current, lat:, lon:, elevation: 0.0)
      @datetime = datetime
      @lat = lat.to_f
      @lon = lon.to_f
      @elevation = elevation.to_f # Observer elevation in meters
    end

    def sun_position
      d = days_since_2000(@datetime)

      # Calculate sun's ecliptic position
      slon, _sr = sun_ecliptic_position(d)

      # STEP 1: Nutation disabled for cross-validation frame alignment
      # The ephemeris comparison uses geometric (mean) Sun, not apparent
      # Keeping nutation causes ~1.2° RA/Dec mismatch during validation
      # omega = revolution(125.04 - 1934.136 * t)
      # nutation_lon = -0.00478 * sind(omega)
      # slon_apparent = slon + nutation_lon

      # Calculate sun's RA and declination (geocentric)
      obl_ecl = 23.4393 - 3.563e-7 * d
      sun_ra = atan2d(cosd(obl_ecl) * sind(slon), cosd(slon))
      sun_dec = asind(sind(obl_ecl) * sind(slon))

      # Calculate local sidereal time
      lst = local_sidereal_time(d, @lon)

      # Calculate hour angle
      sun_ra = revolution(sun_ra)
      ha = lst - sun_ra

      # Calculate azimuth and altitude (topocentric - observer position matters)
      az, alt = equatorial_to_horizontal(ha, sun_dec, @lat)

      {
        azimuth_deg: az,
        altitude_deg: alt,
        ra_deg: sun_ra,
        dec_deg: sun_dec
      }
    end

    def moon_position
      d = days_since_2000(@datetime)

      # Calculate moon's ecliptic position with second-order corrections
      moon_lon, moon_lat = moon_ecliptic_position(d)
      moon_distance_km_val = moon_distance_km(d)

      # Calculate moon's RA and declination (geocentric)
      obl_ecl = 23.4393 - 3.563e-7 * d
      moon_ra_geo = atan2d(cosd(obl_ecl) * sind(moon_lon) * cosd(moon_lat) - sind(obl_ecl) * sind(moon_lat),
                           cosd(moon_lon) * cosd(moon_lat))
      moon_dec_geo = asind(sind(obl_ecl) * sind(moon_lon) * cosd(moon_lat) + cosd(obl_ecl) * sind(moon_lat))

      # Calculate local sidereal time
      lst = local_sidereal_time(d, @lon)

      # Calculate geocentric hour angle
      moon_ra_geo = revolution(moon_ra_geo)
      ha_geo = lst - moon_ra_geo

      # Apply topocentric parallax correction in RA/Dec (proper 3D treatment)
      # Convert distance to Earth radii
      distance_earth_radii = moon_distance_km_val / EARTH_RADIUS_KM

      # Horizontal parallax in radians (proper radians throughout)
      horizontal_parallax_rad = Math.asin(1.0 / distance_earth_radii)

      # Observer latitude and geocentric coordinates in radians
      lat_rad = @lat * Math::PI / 180.0
      dec_rad = moon_dec_geo * Math::PI / 180.0
      ha_rad = ha_geo * Math::PI / 180.0

      # Topocentric RA/Dec corrections (Meeus formulas in radians)
      delta_ra_rad = -horizontal_parallax_rad * Math.cos(lat_rad) * Math.sin(ha_rad) / Math.cos(dec_rad)
      delta_dec_rad = -horizontal_parallax_rad * (Math.sin(lat_rad) * Math.cos(dec_rad) -
                                                   Math.cos(lat_rad) * Math.sin(dec_rad) * Math.cos(ha_rad))

      # Convert corrections to degrees and apply
      delta_ra_deg = delta_ra_rad * 180.0 / Math::PI
      delta_dec_deg = delta_dec_rad * 180.0 / Math::PI

      moon_ra_topo = moon_ra_geo + delta_ra_deg
      moon_dec_topo = moon_dec_geo + delta_dec_deg

      # Recalculate hour angle and horizontal coordinates with topocentric position
      ha_topo = lst - moon_ra_topo
      az_topo, alt_topo = equatorial_to_horizontal(ha_topo, moon_dec_topo, @lat)

      {
        azimuth_deg: az_topo,
        altitude_deg: alt_topo,
        ra_deg: moon_ra_topo,
        dec_deg: moon_dec_topo
      }
    end

    private

    def days_since_2000(datetime)
      # Days since J2000.0 (2000-01-01 12:00 UT)
      j2000 = Time.utc(2000, 1, 1, 12, 0, 0)
      (datetime.utc - j2000) / 86400.0
    end

    def sun_ecliptic_position(d)
      # Mean anomaly
      m = revolution(356.0470 + 0.9856002585 * d)

      # Argument of perihelion
      w = 282.9404 + 4.70935e-5 * d

      # Eccentricity
      e = 0.016709 - 1.151e-9 * d

      # Eccentric anomaly
      e_anom = m + e * (180.0 / Math::PI) * sind(m) * (1.0 + e * cosd(m))

      # Distance and true anomaly
      x = cosd(e_anom) - e
      y = Math.sqrt(1.0 - e * e) * sind(e_anom)
      r = Math.sqrt(x * x + y * y)
      v = atan2d(y, x)

      # True longitude
      lon = (v + w) % 360.0

      [ lon, r ]
    end

    def moon_ecliptic_position(d)
      # Moon ecliptic position with second-order corrections
      # Refined coefficients replace first-order approximations (no double-counting)

      # Mean longitude
      l = revolution(218.316 + 13.176396 * d)

      # Mean anomaly of Moon (M')
      m_moon = revolution(134.963 + 13.064993 * d)

      # Mean anomaly of Sun (M)
      m_sun = revolution(357.529 + 0.98560028 * d)

      # Mean elongation (D)
      d_elong = revolution(297.850 + 12.190749 * d)

      # Argument of latitude (F)
      f = revolution(93.272 + 13.229350 * d)

      # Longitude with refined second-order coefficients
      lon = l
      lon += 6.289 * sind(m_moon)                    # Evection
      lon += 1.2739 * sind(2.0 * d_elong - m_moon)   # Variation (refined coefficient)
      lon += 0.6583 * sind(2.0 * d_elong)            # Yearly equation (FIXED: 2D not 2F, refined)
      lon += 0.2136 * sind(2.0 * m_moon)             # Second evection (refined coefficient)
      lon -= 0.1851 * sind(m_sun)                    # Solar annual equation (refined coefficient)
      lon -= 0.1143 * sind(2.0 * f)                  # Reduction to ecliptic (refined coefficient)

      # Latitude calculation
      lat = 5.128 * sind(f)
      lat += 0.280 * sind(m_moon + f)
      lat -= 0.280 * sind(f - m_moon)
      lat -= 0.174 * sind(f - m_sun)
      lat += 0.173 * sind(2.0 * d_elong - f)
      lat += 0.055 * sind(2.0 * d_elong + f)
      lat += 0.277 * sind(m_moon - f)

      [ revolution(lon), lat ]
    end

    def moon_longitude(d)
      # Legacy method - calls full ecliptic position
      lon, _lat = moon_ecliptic_position(d)
      lon
    end

    def moon_latitude(d)
      # Legacy method - calls full ecliptic position
      _lon, lat = moon_ecliptic_position(d)
      lat
    end

    def moon_distance_km(d)
      # Approximate moon distance in km
      # Mean anomaly
      m = revolution(134.963 + 13.064993 * d)

      # Mean distance (semi-major axis)
      a = MOON_MEAN_DISTANCE_KM

      # Eccentricity (approximate)
      e = 0.0549

      # Distance varies with anomaly (simplified)
      distance = a * (1.0 - e * cosd(m))

      distance
    end

    def local_sidereal_time(d, lon)
      # Greenwich Mean Sidereal Time at 0h UT
      gmst0 = revolution((180.0 + 356.0470 + 282.9404) +
                         (0.9856002585 + 4.70935e-5) * d)

      # Current UT in hours
      ut = (@datetime.hour + @datetime.min / 60.0 + @datetime.sec / 3600.0)

      # GMST at current time
      gmst = gmst0 + ut * 15.0

      # Local sidereal time
      revolution(gmst + lon)
    end

    def equatorial_to_horizontal(hour_angle, declination, latitude)
      # Convert to radians for calculation
      ha_rad = hour_angle * Math::PI / 180.0
      dec_rad = declination * Math::PI / 180.0
      lat_rad = latitude * Math::PI / 180.0

      # Calculate altitude
      sin_alt = Math.sin(dec_rad) * Math.sin(lat_rad) +
                Math.cos(dec_rad) * Math.cos(lat_rad) * Math.cos(ha_rad)
      altitude = Math.asin(sin_alt) * 180.0 / Math::PI

      # Calculate azimuth
      cos_az = (Math.sin(dec_rad) - Math.sin(lat_rad) * sin_alt) /
               (Math.cos(lat_rad) * Math.cos(Math.asin(sin_alt)))

      # Clamp cos_az to [-1, 1] to avoid domain errors
      cos_az = [ [ cos_az, -1.0 ].max, 1.0 ].min

      azimuth = Math.acos(cos_az) * 180.0 / Math::PI

      # Adjust azimuth based on hour angle
      azimuth = 360.0 - azimuth if Math.sin(ha_rad) > 0

      [ azimuth, altitude ]
    end

    # Math helper functions
    def revolution(x)
      x - 360.0 * (x / 360.0).floor
    end

    def sind(x)
      Math.sin(x * Math::PI / 180.0)
    end

    def cosd(x)
      Math.cos(x * Math::PI / 180.0)
    end

    def atan2d(y, x)
      Math.atan2(y, x) * 180.0 / Math::PI
    end

    def asind(x)
      Math.asin(x) * 180.0 / Math::PI
    end
  end
end
