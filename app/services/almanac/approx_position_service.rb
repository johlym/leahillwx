module Almanac
  # Approximate position calculations for real-time "now" positions
  # Based on weewx almanac approximation algorithms via the excellent folks at weewx.com
  # https://github.com/weewx/weewx/blob/master/src/weewx/almanac.py
  class ApproxPositionService
    def initialize(datetime: Time.current, lat:, lon:)
      @datetime = datetime
      @lat = lat.to_f
      @lon = lon.to_f
    end

    def sun_position
      d = days_since_2000(@datetime)

      # Calculate sun's ecliptic position
      slon, _sr = sun_ecliptic_position(d)

      # Calculate sun's RA and declination
      obl_ecl = 23.4393 - 3.563e-7 * d
      sun_ra = atan2d(cosd(obl_ecl) * sind(slon), cosd(slon))
      sun_dec = asind(sind(obl_ecl) * sind(slon))

      # Calculate local sidereal time
      lst = local_sidereal_time(d, @lon)

      # Calculate hour angle
      ha = lst - sun_ra

      # Calculate azimuth and altitude
      az, alt = equatorial_to_horizontal(ha, sun_dec, @lat)

      {
        azimuth: az,
        altitude: alt,
        right_ascension: sun_ra,
        declination: sun_dec
      }
    end

    def moon_position
      d = days_since_2000(@datetime)

      # Simplified moon position calculations
      # These are approximations - real calculations would be more complex
      moon_lon = moon_longitude(d)
      moon_lat = moon_latitude(d)

      # Calculate moon's RA and declination
      obl_ecl = 23.4393 - 3.563e-7 * d
      moon_ra = atan2d(cosd(obl_ecl) * sind(moon_lon), cosd(moon_lon))
      moon_dec = asind(sind(obl_ecl) * sind(moon_lon))

      # Calculate local sidereal time
      lst = local_sidereal_time(d, @lon)

      # Calculate hour angle
      ha = lst - moon_ra

      # Calculate azimuth and altitude
      az, alt = equatorial_to_horizontal(ha, moon_dec, @lat)

      {
        azimuth: az,
        altitude: alt,
        right_ascension: moon_ra,
        declination: moon_dec
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

    def moon_longitude(d)
      # Simplified moon longitude calculation
      # Mean longitude
      l = revolution(218.316 + 13.176396 * d)

      # Mean anomaly
      m = revolution(134.963 + 13.064993 * d)

      # Mean elongation
      f = revolution(93.272 + 13.229350 * d)

      # Longitude calculation with first-order terms
      lon = l + 6.289 * sind(m)
      lon += 1.274 * sind(2.0 * revolution(l - 0) - m)
      lon += 0.658 * sind(2.0 * f)
      lon += 0.214 * sind(2.0 * m)
      lon -= 0.186 * sind(revolution(357.529 + 0.98560028 * d))

      revolution(lon)
    end

    def moon_latitude(d)
      # Simplified - moon latitude is typically small
      # Mean latitude
      f = revolution(93.272 + 13.229350 * d)
      5.128 * sind(f)
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
