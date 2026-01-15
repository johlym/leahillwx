module Almanac
  class EphemGenerator
    TIMEZONE = "America/Los_Angeles"
    BSP_PATH = Rails.root.join("vendor", "de440s.bsp")

    # NAIF IDs for celestial bodies
    SOLAR_SYSTEM_BARYCENTER = 0
    EARTH_MOON_BARYCENTER = 3
    EARTH = 399
    SUN = 10
    MOON = 301

    def initialize
      @lat = ENV.fetch("LOCATION_LAT").to_f
      @lon = ENV.fetch("LOCATION_LON").to_f

      unless File.exist?(BSP_PATH)
        raise "BSP file not found at #{BSP_PATH}. Please place de440s.bsp in vendor/"
      end

      @spk = Ephem::SPK.open(BSP_PATH.to_s)
    end

    def bsp_coverage
      # Using approximate algorithms, so we can support a wide date range
      # Set practical limits for historical and future coverage
      {
        start_date: Date.new(1900, 1, 1),
        end_date: Date.new(2099, 12, 31)
      }
    end

    def generate_daily_entry(date)
      local_date = date.is_a?(Date) ? date : Date.parse(date.to_s)

      # Calculate sun events
      sun_data = calculate_sun_events(local_date)

      # Calculate moon events
      moon_data = calculate_moon_events(local_date)

      # Calculate daylight
      daylight_data = calculate_daylight(sun_data, local_date)

      # Calculate astronomical events
      events_data = calculate_astronomical_events(local_date)

      {
        date: local_date,
        timezone: TIMEZONE,
        **sun_data,
        **daylight_data,
        **moon_data,
        **events_data
      }
    end

    def generate_hourly_positions(date)
      local_date = date.is_a?(Date) ? date : Date.parse(date.to_s)
      positions = []

      (0..23).each do |hour|
        datetime = Time.zone.parse("#{local_date} #{hour}:00:00")
        jd = datetime_to_julian_date(datetime)

        sun_pos = calculate_sun_position_bsp(jd)
        moon_pos = calculate_moon_position_bsp(jd)

        positions << {
          date: local_date,
          hour: hour,
          sun_azimuth_deg: sun_pos[:azimuth],
          sun_altitude_deg: sun_pos[:altitude],
          sun_ra_deg: sun_pos[:ra],
          sun_dec_deg: sun_pos[:dec],
          moon_azimuth_deg: moon_pos[:azimuth],
          moon_altitude_deg: moon_pos[:altitude],
          moon_ra_deg: moon_pos[:ra],
          moon_dec_deg: moon_pos[:dec]
        }
      end

      positions
    end

    private

    def calculate_sun_events(date)
      # Use simple rise/set calculations
      year, month, day = date.year, date.month, date.day

      sunrise_utc, sunset_utc = sun_rise_set(year, month, day, @lon, @lat)
      civil_dawn_utc, civil_dusk_utc = civil_twilight(year, month, day, @lon, @lat)
      solar_noon_utc = (sunrise_utc + sunset_utc) / 2.0

      tz = ActiveSupport::TimeZone[TIMEZONE]

      {
        sunrise_at: utc_hours_to_datetime(year, month, day, sunrise_utc, tz),
        sunset_at: utc_hours_to_datetime(year, month, day, sunset_utc, tz),
        civil_dawn_at: utc_hours_to_datetime(year, month, day, civil_dawn_utc, tz),
        civil_dusk_at: utc_hours_to_datetime(year, month, day, civil_dusk_utc, tz),
        solar_noon_at: utc_hours_to_datetime(year, month, day, solar_noon_utc, tz)
      }
    end

    def calculate_moon_events(date)
      year, month, day = date.year, date.month, date.day

      # Calculate moon rise/set using similar algorithms to sun
      moonrise_utc, moonset_utc = moon_rise_set(year, month, day, @lon, @lat)
      moon_transit_utc = (moonrise_utc + moonset_utc) / 2.0

      # Calculate moon phase
      phase_data = moon_phase(year, month, day)

      tz = ActiveSupport::TimeZone[TIMEZONE]

      {
        moonrise_at: utc_hours_to_datetime(year, month, day, moonrise_utc, tz),
        moonset_at: utc_hours_to_datetime(year, month, day, moonset_utc, tz),
        moon_transit_at: utc_hours_to_datetime(year, month, day, moon_transit_utc, tz),
        moon_phase: phase_data[:phase_name],
        moon_illumination_pct: phase_data[:illumination]
      }
    end

    def calculate_daylight(sun_data, date)
      return {} unless sun_data[:sunrise_at] && sun_data[:sunset_at]

      daylight_seconds = (sun_data[:sunset_at] - sun_data[:sunrise_at]).to_i

      # Calculate yesterday's daylight for delta
      yesterday = date - 1
      yesterday_sun = calculate_sun_events(yesterday)

      daylight_delta_seconds = if yesterday_sun[:sunrise_at] && yesterday_sun[:sunset_at]
        yesterday_daylight = (yesterday_sun[:sunset_at] - yesterday_sun[:sunrise_at]).to_i
        daylight_seconds - yesterday_daylight
      else
        nil
      end

      {
        daylight_seconds: daylight_seconds,
        daylight_delta_seconds: daylight_delta_seconds
      }
    end

    def calculate_astronomical_events(date)
      # These would ideally come from ephem calculations
      # For now, return placeholders - these can be enhanced later
      {
        next_new_moon_at: nil,
        next_full_moon_at: nil,
        next_equinox_at: nil,
        next_solstice_at: nil
      }
    end

    def calculate_sun_position_bsp(jd)
      # Get positions using correct segment chain
      # Sun relative to SSB
      sun_state = @spk[SOLAR_SYSTEM_BARYCENTER, SUN].state_at(jd)

      # Earth position = EMB position + Earth offset from EMB
      emb_state = @spk[SOLAR_SYSTEM_BARYCENTER, EARTH_MOON_BARYCENTER].state_at(jd)
      earth_offset = @spk[EARTH_MOON_BARYCENTER, EARTH].state_at(jd)

      earth_pos = [
        emb_state.position[0] + earth_offset.position[0],
        emb_state.position[1] + earth_offset.position[1],
        emb_state.position[2] + earth_offset.position[2]
      ]

      # Sun relative to Earth
      rel_pos = [
        sun_state.position[0] - earth_pos[0],
        sun_state.position[1] - earth_pos[1],
        sun_state.position[2] - earth_pos[2]
      ]

      # Convert to equatorial and horizontal coordinates
      coords = cartesian_to_equatorial(rel_pos)
      topo = equatorial_to_topocentric(coords[:ra], coords[:dec], jd)

      {
        azimuth: topo[:azimuth],
        altitude: topo[:altitude],
        ra: coords[:ra],
        dec: coords[:dec]
      }
    end

    def calculate_moon_position_bsp(jd)
      # Moon relative to EMB
      moon_offset = @spk[EARTH_MOON_BARYCENTER, MOON].state_at(jd)

      # Earth offset from EMB
      earth_offset = @spk[EARTH_MOON_BARYCENTER, EARTH].state_at(jd)

      # Moon relative to Earth
      rel_pos = [
        moon_offset.position[0] - earth_offset.position[0],
        moon_offset.position[1] - earth_offset.position[1],
        moon_offset.position[2] - earth_offset.position[2]
      ]

      # Convert to equatorial and horizontal coordinates
      coords = cartesian_to_equatorial(rel_pos)
      topo = equatorial_to_topocentric(coords[:ra], coords[:dec], jd)

      {
        azimuth: topo[:azimuth],
        altitude: topo[:altitude],
        ra: coords[:ra],
        dec: coords[:dec]
      }
    end

    def datetime_to_julian_date(datetime)
      # Convert Ruby Time to Julian Date
      # JD = (Unix timestamp / 86400) + 2440587.5
      datetime.to_f / 86400.0 + 2440587.5
    end

    def utc_hours_to_datetime(year, month, day, utc_hours, tz)
      return nil if utc_hours.nil? || utc_hours.nan? || utc_hours.infinite?

      # Handle day overflow (e.g., 24.5 hours = 00:30 next day)
      days_offset = (utc_hours / 24.0).floor
      adjusted_hours = utc_hours - (days_offset * 24.0)

      hours = adjusted_hours.floor
      minutes = ((adjusted_hours - hours) * 60).floor
      seconds = (((adjusted_hours - hours) * 60 - minutes) * 60).floor

      # The rise/set algorithms output UTC hours
      # Create time in UTC, Rails stores it as-is
      base_time = Time.utc(year, month, day, 0, 0, 0)
      base_time + days_offset.days + hours.hours + minutes.minutes + seconds.seconds
    rescue ArgumentError
      nil
    end

    # Sun/Moon rise/set calculations (simplified algorithms)
    def sun_rise_set(year, month, day, lon, lat)
      d = days_since_2000(year, month, day) + 0.5 - (lon / 360.0)

      # Simplified sun position
      slon, _sr = sun_ecliptic_position(d)

      # Calculate rise/set times
      altit = -35.0 / 60.0  # Account for refraction
      sin_dec = sind(23.4393 - 3.563e-7 * d) * sind(slon)
      cos_dec = Math.sqrt(1.0 - sin_dec * sin_dec)

      cost = (sind(altit) - sind(lat) * sin_dec) / (cosd(lat) * cos_dec)

      return [ nil, nil ] if cost >= 1.0 || cost <= -1.0

      t = acosd(cost) / 15.0
      tsouth = 12.0 - rev180(revolution(gmst0(d) + 180.0 + lon) - ra_from_ecliptic(slon, d)) / 15.0

      [ tsouth - t, tsouth + t ]
    end

    def civil_twilight(year, month, day, lon, lat)
      d = days_since_2000(year, month, day) + 0.5 - (lon / 360.0)
      slon, _sr = sun_ecliptic_position(d)

      altit = -6.0  # Civil twilight
      sin_dec = sind(23.4393 - 3.563e-7 * d) * sind(slon)
      cos_dec = Math.sqrt(1.0 - sin_dec * sin_dec)

      cost = (sind(altit) - sind(lat) * sin_dec) / (cosd(lat) * cos_dec)

      return [ nil, nil ] if cost >= 1.0 || cost <= -1.0

      t = acosd(cost) / 15.0
      tsouth = 12.0 - rev180(revolution(gmst0(d) + 180.0 + lon) - ra_from_ecliptic(slon, d)) / 15.0

      [ tsouth - t, tsouth + t ]
    end

    def moon_rise_set(year, month, day, lon, lat)
      # Simplified moon calculations - these are approximations
      # In production, these would use the BSP data more accurately
      sunrise, sunset = sun_rise_set(year, month, day, lon, lat)
      return [ nil, nil ] unless sunrise && sunset

      # Moon rises/sets roughly 50 minutes later each day
      day_of_cycle = ((Time.utc(year, month, day) - Time.utc(2018, 1, 17)) / 86400.0) % 29.530588
      offset = (day_of_cycle / 29.530588) * 24.0

      moonrise = (sunrise + offset) % 24.0
      moonset = (sunset + offset + 12.0) % 24.0

      [ moonrise, moonset ]
    end

    def moon_phase(year, month, day)
      # Reference new moon: 2018-01-17 02:17 UTC
      new_moon_2018 = Time.utc(2018, 1, 17, 2, 17, 0).to_i
      time_ts = Time.utc(year, month, day, 12, 0, 0).to_i

      delta_days = (time_ts - new_moon_2018) / 86400.0
      lunations = delta_days / 29.530588
      position = lunations % 1.0

      illumination = ((1.0 - Math.cos(2.0 * Math::PI * position)) / 2.0 * 100.0).round(1)
      index = ((position * 8) + 0.5).to_i & 7

      phases = [ "new", "waxing crescent", "first quarter", "waxing gibbous",
                "full", "waning gibbous", "last quarter", "waning crescent" ]

      { phase_name: phases[index], illumination: illumination }
    end

    # Helper math functions
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
      # Convert ICRF Cartesian coordinates (km) to RA/Dec (degrees)
      x, y, z = pos

      # Calculate right ascension
      ra = atan2d(y, x)
      ra = ra % 360.0  # Normalize to 0-360

      # Calculate declination
      r = Math.sqrt(x**2 + y**2 + z**2)
      dec = asind(z / r)

      { ra: ra, dec: dec }
    end

    def equatorial_to_topocentric(ra, dec, jd)
      # Convert RA/Dec to Azimuth/Altitude for observer location
      # Calculate Greenwich Mean Sidereal Time
      t = (jd - 2451545.0) / 36525.0  # Julian centuries from J2000
      gmst = 280.46061837 + 360.98564736629 * (jd - 2451545.0) +
             0.000387933 * t**2 - t**3 / 38710000.0
      gmst = gmst % 360.0

      # Calculate Local Sidereal Time
      lst = (gmst + @lon) % 360.0

      # Calculate Hour Angle
      ha = (lst - ra) % 360.0
      ha = ha - 360.0 if ha > 180.0  # Convert to -180 to +180 range

      # Convert to radians for calculation
      ha_rad = ha * Math::PI / 180.0
      dec_rad = dec * Math::PI / 180.0
      lat_rad = @lat * Math::PI / 180.0

      # Calculate altitude
      sin_alt = Math.sin(dec_rad) * Math.sin(lat_rad) +
                Math.cos(dec_rad) * Math.cos(lat_rad) * Math.cos(ha_rad)
      altitude = Math.asin(sin_alt) * 180.0 / Math::PI

      # Calculate azimuth
      cos_az = (Math.sin(dec_rad) - Math.sin(lat_rad) * sin_alt) /
               (Math.cos(lat_rad) * Math.cos(Math.asin(sin_alt)))

      # Clamp to avoid domain errors
      cos_az = [ [ cos_az, -1.0 ].max, 1.0 ].min
      azimuth = Math.acos(cos_az) * 180.0 / Math::PI

      # Adjust azimuth based on hour angle
      azimuth = 360.0 - azimuth if Math.sin(ha_rad) > 0

      { azimuth: azimuth, altitude: altitude }
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

    def jd_to_date(jd)
      # Convert Julian Date to Ruby Date
      # JD 0 is noon January 1, 4713 BC
      # Unix epoch is JD 2440587.5
      time = Time.at((jd - 2440587.5) * 86400.0).utc
      Date.new(time.year, time.month, time.day)
    end
  end
end
