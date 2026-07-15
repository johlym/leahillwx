module Almanac
  class BspPositions
    include MathHelpers

    SOLAR_SYSTEM_BARYCENTER = 0
    EARTH_MOON_BARYCENTER = 3
    EARTH = 399
    SUN = 10
    MOON = 301

    def initialize(spk:, lat:, lon:)
      @spk = spk
      @lat = lat
      @lon = lon
    end

    def sun_position(jd)
      sun_state = @spk[SOLAR_SYSTEM_BARYCENTER, SUN].state_at(jd)
      earth_pos = earth_position(jd)

      rel_pos = [
        sun_state.position[0] - earth_pos[0],
        sun_state.position[1] - earth_pos[1],
        sun_state.position[2] - earth_pos[2]
      ]

      coords = cartesian_to_equatorial(rel_pos)
      topo = equatorial_to_topocentric(coords[:ra], coords[:dec], jd)

      {
        azimuth: topo[:azimuth],
        altitude: topo[:altitude],
        ra: coords[:ra],
        dec: coords[:dec]
      }
    end

    def moon_position(jd)
      moon_offset = @spk[EARTH_MOON_BARYCENTER, MOON].state_at(jd)
      earth_offset = @spk[EARTH_MOON_BARYCENTER, EARTH].state_at(jd)

      rel_pos = [
        moon_offset.position[0] - earth_offset.position[0],
        moon_offset.position[1] - earth_offset.position[1],
        moon_offset.position[2] - earth_offset.position[2]
      ]

      coords = cartesian_to_equatorial(rel_pos)
      topo = equatorial_to_topocentric(coords[:ra], coords[:dec], jd)

      {
        azimuth: topo[:azimuth],
        altitude: topo[:altitude],
        ra: coords[:ra],
        dec: coords[:dec]
      }
    end

    def position_for(body, jd)
      case body
      when :sun then sun_position(jd)
      when :moon then moon_position(jd)
      else raise ArgumentError, "Unknown body: #{body}"
      end
    end

    private

    def earth_position(jd)
      emb_state = @spk[SOLAR_SYSTEM_BARYCENTER, EARTH_MOON_BARYCENTER].state_at(jd)
      earth_offset = @spk[EARTH_MOON_BARYCENTER, EARTH].state_at(jd)

      [
        emb_state.position[0] + earth_offset.position[0],
        emb_state.position[1] + earth_offset.position[1],
        emb_state.position[2] + earth_offset.position[2]
      ]
    end

    def equatorial_to_topocentric(ra, dec, jd)
      t = (jd - 2451545.0) / 36525.0
      gmst = 280.46061837 + 360.98564736629 * (jd - 2451545.0) +
             0.000387933 * t**2 - t**3 / 38710000.0
      gmst = gmst % 360.0

      lst = (gmst + @lon) % 360.0
      ha = (lst - ra) % 360.0
      ha = ha - 360.0 if ha > 180.0

      ha_rad = ha * Math::PI / 180.0
      dec_rad = dec * Math::PI / 180.0
      lat_rad = @lat * Math::PI / 180.0

      sin_alt = Math.sin(dec_rad) * Math.sin(lat_rad) +
                Math.cos(dec_rad) * Math.cos(lat_rad) * Math.cos(ha_rad)
      altitude = Math.asin(sin_alt) * 180.0 / Math::PI

      cos_az = (Math.sin(dec_rad) - Math.sin(lat_rad) * sin_alt) /
               (Math.cos(lat_rad) * Math.cos(Math.asin(sin_alt)))

      cos_az = [[-1.0, cos_az].max, 1.0].min
      azimuth = Math.acos(cos_az) * 180.0 / Math::PI

      azimuth = 360.0 - azimuth if Math.sin(ha_rad) > 0

      { azimuth: azimuth, altitude: altitude }
    end
  end
end
