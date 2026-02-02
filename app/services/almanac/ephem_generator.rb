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

    # Mean obliquity of the ecliptic (J2000.0)
    OBLIQUITY_J2000 = 23.43929111

    def initialize
      @lat = ENV.fetch("LOCATION_LAT").to_f
      @lon = ENV.fetch("LOCATION_LON").to_f
      @season_cache = {}
    end

    def spk
      @spk ||= EphemerisLoader.instance.spk
    end

    def calculate_live_positions(datetime = Time.current)
      Rails.logger.info "Calculating live positions for #{datetime}"
      jd = datetime_to_julian_date(datetime)
      sun_pos = calculate_sun_position_bsp(jd)
      moon_pos = calculate_moon_position_bsp(jd)

      {
        sun: {
          azimuth: sun_pos[:azimuth],
          altitude: sun_pos[:altitude],
          right_ascension: sun_pos[:ra],
          declination: sun_pos[:dec]
        },
        moon: {
          azimuth: moon_pos[:azimuth],
          altitude: moon_pos[:altitude],
          right_ascension: moon_pos[:ra],
          declination: moon_pos[:dec]
        }
      }
    end

    def bsp_coverage
      # Limit to ±50 years from current date for practical coverage
      current_year = Date.current.year
      {
        start_date: Date.new(current_year - 50, 1, 1),
        end_date: Date.new(current_year + 50, 12, 31)
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

      # Calculate season information
      season_data = calculate_season_data(local_date)

      # Calculate distances and 1-minute position data
      distance_data = calculate_distances(local_date)
      position_data = generate_1min_positions(local_date)

      {
        date: local_date,
        timezone: TIMEZONE,
        **sun_data,
        **daylight_data,
        **moon_data,
        **events_data,
        **season_data,
        **distance_data,
        **position_data
      }
    end

    def generate_1min_positions(date)
      # Generate position data every minute (1440 samples per day)
      # Store as compact arrays for efficient storage
      local_date = date.is_a?(Date) ? date : Date.parse(date.to_s)
      tz = ActiveSupport::TimeZone[TIMEZONE]
      day_start = tz.parse("#{local_date} 00:00:00")

      sun_positions = []
      moon_positions = []

      # Sample every minute
      (0...1440).each do |minute|
        datetime = day_start + (minute * 60)
        jd = datetime_to_julian_date(datetime)

        sun_pos = calculate_sun_position_bsp(jd)
        moon_pos = calculate_moon_position_bsp(jd)

        # Store compact format: {m: minute, alt: altitude, az: azimuth}
        sun_positions << {
          m: minute,
          alt: sun_pos[:altitude].round(2),
          az: sun_pos[:azimuth].round(1)
        }

        moon_positions << {
          m: minute,
          alt: moon_pos[:altitude].round(2),
          az: moon_pos[:azimuth].round(1)
        }
      end

      {
        sun_positions_1min: sun_positions,
        moon_positions_1min: moon_positions
      }
    end

    private

    def calculate_sun_events(date)
      # Calculate events for the LOCAL timezone day (midnight to midnight in TIMEZONE)
      # not the UTC day, so events near timezone boundaries are correctly assigned
      tz = ActiveSupport::TimeZone[TIMEZONE]

      # Define the local day boundaries
      day_start = tz.parse("#{date} 00:00:00")
      day_end = day_start + 1.day

      sunrise_time = sun_rise_set_local(day_start, day_end)
      sunset_time = sun_set_local(day_start, day_end)
      civil_dawn_time = civil_dawn_local(day_start, day_end)
      civil_dusk_time = civil_dusk_local(day_start, day_end)
      nautical_dawn_time = nautical_dawn_local(day_start, day_end)
      nautical_dusk_time = nautical_dusk_local(day_start, day_end)
      astronomical_dawn_time = astronomical_dawn_local(day_start, day_end)
      astronomical_dusk_time = astronomical_dusk_local(day_start, day_end)

      # Solar noon is when sun reaches maximum altitude (transit)
      solar_noon_time = sun_transit_local(day_start, day_end)

      {
        sunrise_at: sunrise_time,
        sunset_at: sunset_time,
        civil_dawn_at: civil_dawn_time,
        civil_dusk_at: civil_dusk_time,
        nautical_dawn_at: nautical_dawn_time,
        nautical_dusk_at: nautical_dusk_time,
        astronomical_dawn_at: astronomical_dawn_time,
        astronomical_dusk_at: astronomical_dusk_time,
        solar_noon_at: solar_noon_time
      }
    end

    def calculate_moon_events(date)
      # Calculate events for the LOCAL timezone day (midnight to midnight in TIMEZONE)
      tz = ActiveSupport::TimeZone[TIMEZONE]

      # Define the local day boundaries
      day_start = tz.parse("#{date} 00:00:00")
      day_end = day_start + 1.day

      moonrise_time = moon_rise_local(day_start, day_end)
      moonset_time = moon_set_local(day_start, day_end)
      moon_transit_time = moon_transit_local(day_start, day_end)

      # Calculate moon phase at noon local time
      noon_time = day_start + 12.hours
      phase_data = moon_phase_at_time(noon_time)

      {
        moonrise_at: moonrise_time,
        moonset_at: moonset_time,
        moon_transit_at: moon_transit_time,
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

    def calculate_season_data(date)
      # Store the sun's ecliptic longitude at noon for this date
      # This allows seasons to be calculated dynamically
      datetime = Time.utc(date.year, date.month, date.day, 12, 0, 0)
      jd = datetime_to_julian_date(datetime)

      {
        sun_ecliptic_longitude_deg: solar_ecliptic_longitude(jd)
      }
    end

    def calculate_distances(date)
      # Calculate Earth-Moon and Earth-Sun distances at noon local time
      tz = ActiveSupport::TimeZone[TIMEZONE]
      noon_time = tz.parse("#{date} 12:00:00")
      jd = datetime_to_julian_date(noon_time)

      # Get Sun distance (in AU, convert to km)
      sun_state = spk[SOLAR_SYSTEM_BARYCENTER, SUN].state_at(jd)
      emb_state = spk[SOLAR_SYSTEM_BARYCENTER, EARTH_MOON_BARYCENTER].state_at(jd)
      earth_offset = spk[EARTH_MOON_BARYCENTER, EARTH].state_at(jd)

      earth_pos = [
        emb_state.position[0] + earth_offset.position[0],
        emb_state.position[1] + earth_offset.position[1],
        emb_state.position[2] + earth_offset.position[2]
      ]

      sun_rel_pos = [
        sun_state.position[0] - earth_pos[0],
        sun_state.position[1] - earth_pos[1],
        sun_state.position[2] - earth_pos[2]
      ]

      sun_distance_km = Math.sqrt(
        sun_rel_pos[0]**2 + sun_rel_pos[1]**2 + sun_rel_pos[2]**2
      )

      # Get Moon distance
      moon_state = spk[EARTH_MOON_BARYCENTER, MOON].state_at(jd)
      moon_distance_km = Math.sqrt(
        moon_state.position[0]**2 + moon_state.position[1]**2 + moon_state.position[2]**2
      )

      {
        sun_distance_km: sun_distance_km,
        moon_distance_km: moon_distance_km
      }
    end

    def calculate_sun_position_bsp(jd)
      # Get positions using correct segment chain
      # Sun relative to SSB
      sun_state = spk[SOLAR_SYSTEM_BARYCENTER, SUN].state_at(jd)

      # Earth position = EMB position + Earth offset from EMB
      emb_state = spk[SOLAR_SYSTEM_BARYCENTER, EARTH_MOON_BARYCENTER].state_at(jd)
      earth_offset = spk[EARTH_MOON_BARYCENTER, EARTH].state_at(jd)

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
      moon_offset = spk[EARTH_MOON_BARYCENTER, MOON].state_at(jd)

      # Earth offset from EMB
      earth_offset = spk[EARTH_MOON_BARYCENTER, EARTH].state_at(jd)

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

    # Local timezone event search helpers
    def sun_rise_set_local(day_start, day_end)
      # Search for sunrise within the local timezone day
      find_horizon_crossing(day_start, day_end, :sun, -35.0 / 60.0, :rising)
    end

    def sun_set_local(day_start, day_end)
      # Search for sunset within the local timezone day
      find_horizon_crossing(day_start, day_end, :sun, -35.0 / 60.0, :setting)
    end

    def civil_dawn_local(day_start, day_end)
      # Search for civil dawn within the local timezone day
      find_horizon_crossing(day_start, day_end, :sun, -6.0, :rising)
    end

    def civil_dusk_local(day_start, day_end)
      # Search for civil dusk within the local timezone day
      find_horizon_crossing(day_start, day_end, :sun, -6.0, :setting)
    end

    def nautical_dawn_local(day_start, day_end)
      # Search for nautical dawn within the local timezone day (sun at -12°)
      find_horizon_crossing(day_start, day_end, :sun, -12.0, :rising)
    end

    def nautical_dusk_local(day_start, day_end)
      # Search for nautical dusk within the local timezone day (sun at -12°)
      find_horizon_crossing(day_start, day_end, :sun, -12.0, :setting)
    end

    def astronomical_dawn_local(day_start, day_end)
      # Search for astronomical dawn within the local timezone day (sun at -18°)
      find_horizon_crossing(day_start, day_end, :sun, -18.0, :rising)
    end

    def astronomical_dusk_local(day_start, day_end)
      # Search for astronomical dusk within the local timezone day (sun at -18°)
      find_horizon_crossing(day_start, day_end, :sun, -18.0, :setting)
    end

    def moon_rise_local(day_start, day_end)
      # Search for moonrise within the local timezone day
      find_horizon_crossing(day_start, day_end, :moon, -49.0 / 60.0, :rising)
    end

    def moon_set_local(day_start, day_end)
      # Search for moonset within the local timezone day
      find_horizon_crossing(day_start, day_end, :moon, -49.0 / 60.0, :setting)
    end

    def sun_transit_local(day_start, day_end)
      # Find sun transit (highest altitude) within the local timezone day
      find_transit(day_start, day_end, :sun)
    end

    def moon_transit_local(day_start, day_end)
      # Find moon transit (highest altitude) within the local timezone day
      find_transit(day_start, day_end, :moon)
    end

    def find_horizon_crossing(day_start, day_end, body, horizon_alt, direction)
      # Sample every 5 minutes to find horizon crossing
      prev_alt = nil
      prev_time = nil

      samples = 288  # Every 5 minutes for 24 hours
      interval = (day_end - day_start) / samples.to_f

      (0..samples).each do |i|
        current_time = day_start + (i * interval)
        jd = datetime_to_julian_date(current_time)

        pos = if body == :sun
          calculate_sun_position_bsp(jd)
        else
          calculate_moon_position_bsp(jd)
        end

        current_alt = pos[:altitude]

        if prev_alt && prev_time
          # Check for horizon crossing
          if direction == :rising && prev_alt < horizon_alt && current_alt >= horizon_alt
            # Interpolate to find precise crossing time
            fraction = (horizon_alt - prev_alt) / (current_alt - prev_alt)
            crossing_time = prev_time + (fraction * (current_time - prev_time))
            return crossing_time
          elsif direction == :setting && prev_alt >= horizon_alt && current_alt < horizon_alt
            # Interpolate to find precise crossing time
            fraction = (prev_alt - horizon_alt) / (prev_alt - current_alt)
            crossing_time = prev_time + (fraction * (current_time - prev_time))
            return crossing_time
          end
        end

        prev_alt = current_alt
        prev_time = current_time
      end

      nil  # No crossing found
    end

    def find_transit(day_start, day_end, body)
      # Find the time of maximum altitude within the local timezone day
      max_altitude = -999.0
      transit_time = nil

      samples = 288  # Every 5 minutes for 24 hours
      interval = (day_end - day_start) / samples.to_f

      (0..samples).each do |i|
        current_time = day_start + (i * interval)
        jd = datetime_to_julian_date(current_time)

        pos = if body == :sun
          calculate_sun_position_bsp(jd)
        else
          calculate_moon_position_bsp(jd)
        end

        if pos[:altitude] > max_altitude
          max_altitude = pos[:altitude]
          transit_time = current_time
        end
      end

      transit_time
    end

    def moon_phase_at_time(time)
      # Reference new moon: 2018-01-17 02:17 UTC
      new_moon_2018 = Time.utc(2018, 1, 17, 2, 17, 0).to_i
      time_ts = time.to_i

      delta_days = (time_ts - new_moon_2018) / 86400.0
      lunations = delta_days / 29.530588
      position = lunations % 1.0

      illumination = ((1.0 - Math.cos(2.0 * Math::PI * position)) / 2.0 * 100.0).round(1)
      index = ((position * 8) + 0.5).to_i & 7

      phases = [ "new", "waxing crescent", "first quarter", "waxing gibbous",
                "full", "waning gibbous", "last quarter", "waning crescent" ]

      { phase_name: phases[index], illumination: illumination }
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
      # Find moon rise/set by detecting horizon crossings
      # Using similar approach to weewx Sun.py but adapted for the moon

      # Horizon correction for moon rise/set:
      # - Atmospheric refraction: ~34 arcminutes = 34/60 degrees
      # - Moon's average apparent radius: ~15 arcminutes = 15/60 degrees
      # - Total correction for upper limb: -(34+15)/60 = -49/60 = -0.817 degrees
      # (negative because we want to detect when upper limb crosses horizon)
      horizon_alt = -49.0 / 60.0

      moonrise_utc = nil
      moonset_utc = nil

      # Sample every 5 minutes throughout the day for better precision
      prev_alt = nil
      prev_hour = nil

      (0..287).each do |i|  # 288 samples = every 5 minutes for 24 hours
        hour_decimal = i / 12.0  # Convert to hours (12 samples per hour)

        # Create datetime for this sample
        datetime = Time.utc(year, month, day, 0, 0, 0) + (hour_decimal * 3600)
        jd = datetime_to_julian_date(datetime)

        # Get moon position at this time
        moon_pos = calculate_moon_position_bsp(jd)
        current_alt = moon_pos[:altitude]

        # Check for horizon crossing relative to corrected horizon
        if prev_alt && prev_hour
          # Rising: altitude goes from below to above the corrected horizon
          if prev_alt < horizon_alt && current_alt >= horizon_alt && moonrise_utc.nil?
            # Interpolate to find more precise crossing time
            fraction = (horizon_alt - prev_alt) / (current_alt - prev_alt)
            moonrise_utc = prev_hour + fraction * (hour_decimal - prev_hour)
          end

          # Setting: altitude goes from above to below the corrected horizon
          if prev_alt >= horizon_alt && current_alt < horizon_alt && moonset_utc.nil?
            # Interpolate to find more precise crossing time
            fraction = (prev_alt - horizon_alt) / (prev_alt - current_alt)
            moonset_utc = prev_hour + fraction * (hour_decimal - prev_hour)
          end
        end

        prev_alt = current_alt
        prev_hour = hour_decimal

        # Break early if we found both
        break if moonrise_utc && moonset_utc
      end

      # Handle cases where moon doesn't rise or set on this day
      # (e.g., circumpolar moon near poles, or moon always below/above horizon)

      [ moonrise_utc, moonset_utc ]
    end

    def moon_transit(year, month, day, lon, lat)
      # Find moon transit (highest altitude point) by sampling throughout the day
      # This works even when moon doesn't rise or set on the given day

      max_altitude = -999.0
      transit_utc = nil

      # Sample every 5 minutes throughout the day for precision
      (0..287).each do |i|  # 288 samples = every 5 minutes for 24 hours
        hour_decimal = i / 12.0  # Convert to hours (12 samples per hour)

        # Create datetime for this sample
        datetime = Time.utc(year, month, day, 0, 0, 0) + (hour_decimal * 3600)
        jd = datetime_to_julian_date(datetime)

        # Get moon position at this time
        moon_pos = calculate_moon_position_bsp(jd)
        current_alt = moon_pos[:altitude]

        # Track maximum altitude
        if current_alt > max_altitude
          max_altitude = current_alt
          transit_utc = hour_decimal
        end
      end

      transit_utc
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

    def solar_ecliptic_longitude(jd)
      # Calculate the Sun's apparent geocentric ecliptic longitude using DE440
      # This is used to determine astronomical seasons

      # Get Sun position relative to SSB
      sun_state = spk[SOLAR_SYSTEM_BARYCENTER, SUN].state_at(jd)

      # Get Earth position relative to SSB
      emb_state = spk[SOLAR_SYSTEM_BARYCENTER, EARTH_MOON_BARYCENTER].state_at(jd)
      earth_offset = spk[EARTH_MOON_BARYCENTER, EARTH].state_at(jd)

      earth_pos = [
        emb_state.position[0] + earth_offset.position[0],
        emb_state.position[1] + earth_offset.position[1],
        emb_state.position[2] + earth_offset.position[2]
      ]

      # Sun relative to Earth (geocentric)
      rel_pos = [
        sun_state.position[0] - earth_pos[0],
        sun_state.position[1] - earth_pos[1],
        sun_state.position[2] - earth_pos[2]
      ]

      # ICRF positions are in equatorial coordinates (J2000)
      # Rotate to ecliptic coordinates using obliquity
      x_eq, y_eq, z_eq = rel_pos
      eps_rad = OBLIQUITY_J2000 * Math::PI / 180.0

      # Rotation matrix from equatorial to ecliptic
      # x_ecl = x_eq
      # y_ecl = y_eq * cos(eps) + z_eq * sin(eps)
      # z_ecl = -y_eq * sin(eps) + z_eq * cos(eps)
      x_ecl = x_eq
      y_ecl = y_eq * Math.cos(eps_rad) + z_eq * Math.sin(eps_rad)
      _z_ecl = -y_eq * Math.sin(eps_rad) + z_eq * Math.cos(eps_rad)

      # Calculate ecliptic longitude
      lambda = Math.atan2(y_ecl, x_ecl) * 180.0 / Math::PI
      lambda = lambda % 360.0  # Normalize to [0, 360)

      lambda
    end

    def find_season_boundary(year, target_longitude)
      # Find the Julian Date when the Sun's ecliptic longitude equals target_longitude
      # Uses bisection method for robustness

      # Determine search range based on target longitude
      # These are approximate starting points for each season
      search_ranges = {
        0 => [ 3, 20, 3, 21 ],      # Vernal Equinox: March 19-21
        90 => [ 6, 20, 6, 22 ],     # Summer Solstice: June 20-22
        180 => [ 9, 21, 9, 23 ],    # Autumnal Equinox: September 21-23
        270 => [ 12, 20, 12, 23 ]   # Winter Solstice: December 20-23
      }

      range = search_ranges[target_longitude]
      raise "Invalid target longitude: #{target_longitude}" unless range

      start_month, start_day, end_month, end_day = range

      # Create JD range for search
      jd_start = datetime_to_julian_date(Time.utc(year, start_month, start_day, 0, 0, 0))
      jd_end = datetime_to_julian_date(Time.utc(year, end_month, end_day, 23, 59, 59))

      # Bisection method to find when longitude crosses target
      tolerance = 1e-6  # ~0.1 seconds precision

      jd_low = jd_start
      jd_high = jd_end

      # Handle angle wrapping for vernal equinox (0° = 360°)
      lambda_low = solar_ecliptic_longitude(jd_low)
      lambda_high = solar_ecliptic_longitude(jd_high)

      # For vernal equinox, we need to handle 360° -> 0° transition
      if target_longitude == 0
        # Adjust angles to be relative to 360° for comparison
        lambda_low = lambda_low < 180 ? lambda_low + 360 : lambda_low
        lambda_high = lambda_high < 180 ? lambda_high + 360 : lambda_high
        target_adjusted = 360.0
      else
        target_adjusted = target_longitude.to_f
      end

      # Bisection
      while (jd_high - jd_low) > tolerance
        jd_mid = (jd_low + jd_high) / 2.0
        lambda_mid = solar_ecliptic_longitude(jd_mid)

        # Adjust for vernal equinox wrapping
        if target_longitude == 0
          lambda_mid = lambda_mid < 180 ? lambda_mid + 360 : lambda_mid
        end

        if lambda_mid < target_adjusted
          jd_low = jd_mid
          lambda_low = lambda_mid
        else
          jd_high = jd_mid
          lambda_high = lambda_mid
        end
      end

      # Return the midpoint as best estimate
      (jd_low + jd_high) / 2.0
    end

    def astronomical_seasons_for_year(year)
      # Return cached result if available
      return @season_cache[year] if @season_cache[year]

      # Compute season boundaries for the given year
      seasons = {
        spring_equinox: nil,
        summer_solstice: nil,
        autumn_equinox: nil,
        winter_solstice: nil
      }

      # Find each season boundary
      begin
        # Vernal Equinox (λ = 0°)
        jd = find_season_boundary(year, 0)
        seasons[:spring_equinox] = jd_to_time(jd)

        # Summer Solstice (λ = 90°)
        jd = find_season_boundary(year, 90)
        seasons[:summer_solstice] = jd_to_time(jd)

        # Autumnal Equinox (λ = 180°)
        jd = find_season_boundary(year, 180)
        seasons[:autumn_equinox] = jd_to_time(jd)

        # Winter Solstice (λ = 270°)
        jd = find_season_boundary(year, 270)
        seasons[:winter_solstice] = jd_to_time(jd)
      rescue => e
        Rails.logger.warn "Failed to calculate seasons for #{year}: #{e.message}"
      end

      # Cache the result
      @season_cache[year] = seasons

      seasons
    end

    def season_for_date(date)
      # Determine which astronomical season a given date falls into
      year = date.year

      # Get season boundaries for this year
      current_year_seasons = astronomical_seasons_for_year(year)

      # Convert date to Time for comparison
      date_time = Time.utc(date.year, date.month, date.day, 12, 0, 0)

      # Determine season based on date
      case
      when current_year_seasons[:winter_solstice] && date_time >= current_year_seasons[:winter_solstice] then :winter
      when current_year_seasons[:autumn_equinox] && date_time >= current_year_seasons[:autumn_equinox] then :fall
      when current_year_seasons[:summer_solstice] && date_time >= current_year_seasons[:summer_solstice] then :summer
      when current_year_seasons[:spring_equinox] && date_time >= current_year_seasons[:spring_equinox] then :spring
      else :winter
      end
    end

    def jd_to_time(jd)
      # Convert Julian Date to Ruby Time (UTC)
      Time.at((jd - 2440587.5) * 86400.0).utc
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
