module Almanac
  class EphemGenerator
    include MathHelpers

    TIMEZONE = "America/Los_Angeles"
    BSP_PATH = Rails.root.join("vendor", "de440s.bsp")

    SOLAR_SYSTEM_BARYCENTER = 0
    EARTH_MOON_BARYCENTER = 3
    EARTH = 399
    SUN = 10
    MOON = 301

    OBLIQUITY_J2000 = 23.43929111

    def initialize
      @lat = ENV.fetch("LOCATION_LAT").to_f
      @lon = ENV.fetch("LOCATION_LON").to_f
      @seasons = Seasons.new(spk_provider: self)
    end

    def spk
      @spk ||= EphemerisLoader.instance.spk
    end

    def bsp_positions
      @bsp_positions ||= BspPositions.new(spk: spk, lat: @lat, lon: @lon)
    end

    def horizon_events
      @horizon_events ||= HorizonEvents.new(bsp_positions: bsp_positions)
    end

    def calculate_live_positions(datetime = Time.current)
      Rails.logger.info "Calculating live positions for #{datetime}"
      jd = datetime_to_julian_date(datetime)
      sun_pos = bsp_positions.sun_position(jd)
      moon_pos = bsp_positions.moon_position(jd)

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
      current_year = Date.current.year
      {
        start_date: Date.new(current_year - 50, 1, 1),
        end_date: Date.new(current_year + 50, 12, 31)
      }
    end

    def generate_daily_entry(date)
      local_date = date.is_a?(Date) ? date : Date.parse(date.to_s)

      sun_data = calculate_sun_events(local_date)
      moon_data = calculate_moon_events(local_date)
      daylight_data = calculate_daylight(sun_data, local_date)
      events_data = calculate_astronomical_events(local_date)
      season_data = calculate_season_data(local_date)
      distance_data = calculate_distances(local_date)
      position_data = generate_hourly_positions(local_date)

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

    def generate_hourly_positions(date)
      local_date = date.is_a?(Date) ? date : Date.parse(date.to_s)
      tz = ActiveSupport::TimeZone[TIMEZONE]
      day_start = tz.parse("#{local_date} 00:00:00")

      sun_positions = []
      moon_positions = []

      (0...24).each do |hour|
        datetime = day_start + (hour * 3600)
        jd = datetime_to_julian_date(datetime)

        sun_pos = bsp_positions.sun_position(jd)
        moon_pos = bsp_positions.moon_position(jd)

        sun_positions << {
          h: hour,
          alt: sun_pos[:altitude].round(2),
          az: sun_pos[:azimuth].round(1)
        }

        moon_positions << {
          h: hour,
          alt: moon_pos[:altitude].round(2),
          az: moon_pos[:azimuth].round(1)
        }
      end

      {
        sun_positions_hourly: sun_positions,
        moon_positions_hourly: moon_positions
      }
    end

    def astronomical_seasons_for_year(year)
      seasons.astronomical_seasons_for_year(year)
    end

    def season_for_date(date)
      seasons.season_for_date(date)
    end

    private

    def seasons
      @seasons
    end

    def calculate_sun_events(date)
      tz = ActiveSupport::TimeZone[TIMEZONE]
      day_start = tz.parse("#{date} 00:00:00")
      day_end = day_start + 1.day

      {
        sunrise_at: horizon_events.sun_rise(day_start, day_end),
        sunset_at: horizon_events.sun_set(day_start, day_end),
        civil_dawn_at: horizon_events.civil_dawn(day_start, day_end),
        civil_dusk_at: horizon_events.civil_dusk(day_start, day_end),
        nautical_dawn_at: horizon_events.nautical_dawn(day_start, day_end),
        nautical_dusk_at: horizon_events.nautical_dusk(day_start, day_end),
        astronomical_dawn_at: horizon_events.astronomical_dawn(day_start, day_end),
        astronomical_dusk_at: horizon_events.astronomical_dusk(day_start, day_end),
        solar_noon_at: horizon_events.sun_transit(day_start, day_end)
      }
    end

    def calculate_moon_events(date)
      tz = ActiveSupport::TimeZone[TIMEZONE]
      day_start = tz.parse("#{date} 00:00:00")
      day_end = day_start + 1.day

      noon_time = day_start + 12.hours
      phase_data = moon_phase_at_time(noon_time)

      {
        moonrise_at: horizon_events.moon_rise(day_start, day_end),
        moonset_at: horizon_events.moon_set(day_start, day_end),
        moon_transit_at: horizon_events.moon_transit(day_start, day_end),
        moon_phase: phase_data[:phase_name],
        moon_illumination_pct: phase_data[:illumination]
      }
    end

    def calculate_daylight(sun_data, date)
      return {} unless sun_data[:sunrise_at] && sun_data[:sunset_at]

      daylight_seconds = (sun_data[:sunset_at] - sun_data[:sunrise_at]).to_i

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
      {
        next_new_moon_at: nil,
        next_full_moon_at: nil,
        next_equinox_at: nil,
        next_solstice_at: nil
      }
    end

    def calculate_season_data(date)
      datetime = Time.utc(date.year, date.month, date.day, 12, 0, 0)
      jd = datetime_to_julian_date(datetime)

      {
        sun_ecliptic_longitude_deg: seasons.solar_ecliptic_longitude(jd)
      }
    end

    def calculate_distances(date)
      tz = ActiveSupport::TimeZone[TIMEZONE]
      noon_time = tz.parse("#{date} 12:00:00")
      jd = datetime_to_julian_date(noon_time)

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

      moon_state = spk[EARTH_MOON_BARYCENTER, MOON].state_at(jd)
      moon_distance_km = Math.sqrt(
        moon_state.position[0]**2 + moon_state.position[1]**2 + moon_state.position[2]**2
      )

      {
        sun_distance_km: sun_distance_km,
        moon_distance_km: moon_distance_km
      }
    end

    def moon_phase_at_time(time)
      new_moon_2018 = Time.utc(2018, 1, 17, 2, 17, 0).to_i
      time_ts = time.to_i

      delta_days = (time_ts - new_moon_2018) / 86400.0
      lunations = delta_days / 29.530588
      position = lunations % 1.0

      illumination = ((1.0 - Math.cos(2.0 * Math::PI * position)) / 2.0 * 100.0).round(1)
      index = ((position * 8) + 0.5).to_i & 7

      phases = ["new", "waxing crescent", "first quarter", "waxing gibbous",
                "full", "waning gibbous", "last quarter", "waning crescent"]

      { phase_name: phases[index], illumination: illumination }
    end
  end
end
