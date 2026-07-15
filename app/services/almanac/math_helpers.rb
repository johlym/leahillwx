module Almanac
  module MathHelpers
    def datetime_to_julian_date(datetime)
      datetime.to_f / 86400.0 + 2440587.5
    end

    def jd_to_time(jd)
      Time.at((jd - 2440587.5) * 86400.0).utc
    end

    def jd_to_date(jd)
      time = Time.at((jd - 2440587.5) * 86400.0).utc
      Date.new(time.year, time.month, time.day)
    end

    def days_since_2000(year, month, day)
      367.0 * year - ((7.0 * (year + ((month + 9.0) / 12.0))) / 4.0) +
        (275.0 * month / 9.0) + day - 730530.0
    end

    def sun_ecliptic_position(d)
      m = revolution(356.0470 + 0.9856002585 * d)
      w = 282.9404 + 4.70935e-5 * d
      e = 0.016709 - 1.151e-9 * d

      e_anom = m + e * (180.0 / Math::PI) * sind(m) * (1.0 + e * cosd(m))
      x = cosd(e_anom) - e
      y = Math.sqrt(1.0 - e * e) * sind(e_anom)
      _r = Math.sqrt(x * x + y * y)
      v = atan2d(y, x)
      lon = (v + w) % 360.0

      [ lon, _r ]
    end

    def ra_from_ecliptic(lon, d)
      obl_ecl = 23.4393 - 3.563e-7 * d
      x = cosd(lon)
      y = cosd(obl_ecl) * sind(lon)
      atan2d(y, x)
    end

    def gmst0(d)
      revolution((180.0 + 356.0470 + 282.9404) + (0.9856002585 + 4.70935e-5) * d)
    end

    def cartesian_to_equatorial(pos)
      x, y, z = pos

      ra = atan2d(y, x)
      ra = ra % 360.0

      r = Math.sqrt(x**2 + y**2 + z**2)
      dec = asind(z / r)

      { ra: ra, dec: dec }
    end

    def revolution(x)
      x - 360.0 * (x / 360.0).floor
    end

    def rev180(x)
      x - 360.0 * ((x / 360.0 + 0.5).floor)
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

    def acosd(x)
      Math.acos(x) * 180.0 / Math::PI
    end

    def asind(x)
      Math.asin(x) * 180.0 / Math::PI
    end
  end
end
