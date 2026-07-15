module Almanac
  class Seasons
    include MathHelpers

    SOLAR_SYSTEM_BARYCENTER = 0
    EARTH_MOON_BARYCENTER = 3
    EARTH = 399
    SUN = 10

    OBLIQUITY_J2000 = 23.43929111

    def initialize(spk_provider:)
      @spk_provider = spk_provider
      @season_cache = {}
    end

    def astronomical_seasons_for_year(year)
      return @season_cache[year] if @season_cache[year]

      seasons = {
        spring_equinox: nil,
        summer_solstice: nil,
        autumn_equinox: nil,
        winter_solstice: nil
      }

      begin
        jd = find_season_boundary(year, 0)
        seasons[:spring_equinox] = jd_to_time(jd)

        jd = find_season_boundary(year, 90)
        seasons[:summer_solstice] = jd_to_time(jd)

        jd = find_season_boundary(year, 180)
        seasons[:autumn_equinox] = jd_to_time(jd)

        jd = find_season_boundary(year, 270)
        seasons[:winter_solstice] = jd_to_time(jd)
      rescue => e
        Rails.logger.warn "Failed to calculate seasons for #{year}: #{e.message}"
      end

      @season_cache[year] = seasons
      seasons
    end

    def season_for_date(date)
      year = date.year
      current_year_seasons = astronomical_seasons_for_year(year)
      date_time = Time.utc(date.year, date.month, date.day, 12, 0, 0)

      case
      when current_year_seasons[:winter_solstice] && date_time >= current_year_seasons[:winter_solstice] then :winter
      when current_year_seasons[:autumn_equinox] && date_time >= current_year_seasons[:autumn_equinox] then :fall
      when current_year_seasons[:summer_solstice] && date_time >= current_year_seasons[:summer_solstice] then :summer
      when current_year_seasons[:spring_equinox] && date_time >= current_year_seasons[:spring_equinox] then :spring
      else :winter
      end
    end

    def solar_ecliptic_longitude(jd)
      sun_state = spk[SOLAR_SYSTEM_BARYCENTER, SUN].state_at(jd)

      emb_state = spk[SOLAR_SYSTEM_BARYCENTER, EARTH_MOON_BARYCENTER].state_at(jd)
      earth_offset = spk[EARTH_MOON_BARYCENTER, EARTH].state_at(jd)

      earth_pos = [
        emb_state.position[0] + earth_offset.position[0],
        emb_state.position[1] + earth_offset.position[1],
        emb_state.position[2] + earth_offset.position[2]
      ]

      rel_pos = [
        sun_state.position[0] - earth_pos[0],
        sun_state.position[1] - earth_pos[1],
        sun_state.position[2] - earth_pos[2]
      ]

      x_eq, y_eq, z_eq = rel_pos
      eps_rad = OBLIQUITY_J2000 * Math::PI / 180.0

      x_ecl = x_eq
      y_ecl = y_eq * Math.cos(eps_rad) + z_eq * Math.sin(eps_rad)

      lambda = Math.atan2(y_ecl, x_ecl) * 180.0 / Math::PI
      lambda % 360.0
    end

    private

    def spk
      @spk_provider.spk
    end

    def find_season_boundary(year, target_longitude)
      search_ranges = {
        0 => [ 3, 20, 3, 21 ],
        90 => [ 6, 20, 6, 22 ],
        180 => [ 9, 21, 9, 23 ],
        270 => [ 12, 20, 12, 23 ]
      }

      range = search_ranges[target_longitude]
      raise "Invalid target longitude: #{target_longitude}" unless range

      start_month, start_day, end_month, end_day = range

      jd_start = datetime_to_julian_date(Time.utc(year, start_month, start_day, 0, 0, 0))
      jd_end = datetime_to_julian_date(Time.utc(year, end_month, end_day, 23, 59, 59))

      tolerance = 1e-6

      jd_low = jd_start
      jd_high = jd_end

      lambda_low = solar_ecliptic_longitude(jd_low)
      lambda_high = solar_ecliptic_longitude(jd_high)

      if target_longitude == 0
        lambda_low = lambda_low < 180 ? lambda_low + 360 : lambda_low
        lambda_high = lambda_high < 180 ? lambda_high + 360 : lambda_high
        target_adjusted = 360.0
      else
        target_adjusted = target_longitude.to_f
      end

      while (jd_high - jd_low) > tolerance
        jd_mid = (jd_low + jd_high) / 2.0
        lambda_mid = solar_ecliptic_longitude(jd_mid)

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

      (jd_low + jd_high) / 2.0
    end
  end
end
