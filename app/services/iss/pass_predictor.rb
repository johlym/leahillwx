# frozen_string_literal: true

module Iss
  # Samples SGP4 + astronoby look angles to find upcoming ISS passes.
  class PassPredictor
    COMPASS = %w[
      N NNE NE ENE E ESE SE SSE
      S SSW SW WSW W WNW NW NNW
    ].freeze

    MIN_ELEVATION_DEG = 10.0
    SAMPLE_SECONDS = 30
    HORIZON_HOURS = 36

    def initialize(
      tle:,
      lat: ENV.fetch("LOCATION_LAT").to_f,
      lon: ENV.fetch("LOCATION_LON").to_f,
      elevation_m: 0.0
    )
      @tle = tle
      @propagator = Sgp4.new(tle)
      @lat = lat
      @lon = lon
      @observer = Astronoby::Observer.new(
        latitude: Astronoby::Angle.from_degrees(lat),
        longitude: Astronoby::Angle.from_degrees(lon),
        elevation: Astronoby::Distance.from_meters(elevation_m)
      )
    end

    def predict(from: Time.current.utc, hours: HORIZON_HOURS)
      samples = sample_window(from, from + hours.hours)
      passes = extract_passes(samples)
      passes.map { |pass| decorate(pass) }
    end

    private

    def sample_window(start_time, end_time)
      samples = []
      t = start_time.utc
      while t <= end_time
        samples << look_angle_at(t)
        t += SAMPLE_SECONDS
      end
      samples.compact
    end

    def look_angle_at(time)
      state = @propagator.propagate(time)
      instant = Astronoby::Instant.from_time(time)
      teme = Astronoby::Teme.new(
        position: Astronoby::Distance.vector_from_meters(state[:position_m]),
        velocity: Astronoby::Velocity.vector_from_mps(state[:velocity_mps]),
        instant: instant
      )
      topo = teme.observed_by(@observer)
      horizontal = topo.horizontal

      {
        at: time,
        az: horizontal.azimuth.degrees,
        alt: horizontal.altitude.degrees,
        sunlit: sunlit?(state[:position_m], time)
      }
    rescue Iss::Sgp4::PropagationError, Astronoby::IncompatibleArgumentsError, StandardError => e
      Rails.logger.debug { "ISS sample skipped at #{time}: #{e.message}" }
      nil
    end

    def extract_passes(samples)
      passes = []
      current = nil

      samples.each do |sample|
        above = sample[:alt] >= MIN_ELEVATION_DEG
        if above && current.nil?
          current = {
            aos: sample,
            los: sample,
            max: sample,
            points: [ sample ]
          }
        elsif above && current
          current[:los] = sample
          current[:points] << sample
          current[:max] = sample if sample[:alt] > current[:max][:alt]
        elsif !above && current
          passes << current
          current = nil
        end
      end
      passes << current if current
      passes
    end

    def decorate(pass)
      aos = pass[:aos]
      los = pass[:los]
      max = pass[:max]
      site_dark = site_dark?(aos[:at]) && site_dark?(los[:at])
      visible = site_dark && max[:sunlit]

      {
        aos_at: aos[:at],
        los_at: los[:at],
        aos_az: aos[:az],
        los_az: los[:az],
        max_el: max[:alt],
        max_el_az: max[:az],
        duration_s: (los[:at] - aos[:at]).to_i,
        visible: visible
      }
    end

    # Simple cylindrical Earth-shadow test in TEME/ECI-ish space.
    def sunlit?(sat_position_m, time)
      sun = sun_unit_vector(time)
      # Satellite is in shadow if behind Earth and within the cylinder.
      r_sat = sat_position_m
      # Projection of sat onto anti-sun axis
      along = r_sat[0] * -sun[0] + r_sat[1] * -sun[1] + r_sat[2] * -sun[2]
      return true if along <= 0

      radial2 = r_sat[0]**2 + r_sat[1]**2 + r_sat[2]**2 - along**2
      earth_r = 6_378_137.0
      radial2 > earth_r**2
    end

    def sun_unit_vector(time)
      # Approximate sun direction from GMST / ecliptic longitude (low precision OK for shadow).
      jd = time.to_f / 86_400.0 + 2_440_587.5
      n = jd - 2_451_545.0
      l = (280.460 + 0.9856474 * n) % 360
      g = ((357.528 + 0.9856003 * n) % 360) * Math::PI / 180.0
      lambda = (l + 1.915 * Math.sin(g) + 0.020 * Math.sin(2 * g)) * Math::PI / 180.0
      epsilon = (23.439 - 0.0000004 * n) * Math::PI / 180.0
      x = Math.cos(lambda)
      y = Math.cos(epsilon) * Math.sin(lambda)
      z = Math.sin(epsilon) * Math.sin(lambda)
      norm = Math.sqrt(x * x + y * y + z * z)
      [ x / norm, y / norm, z / norm ]
    end

    def site_dark?(time)
      # Sun altitude < -6° (civil twilight) using a coarse solar model.
      lat = @lat * Math::PI / 180.0
      jd = time.to_f / 86_400.0 + 2_440_587.5
      n = jd - 2_451_545.0
      l = (280.460 + 0.9856474 * n) % 360
      g = ((357.528 + 0.9856003 * n) % 360) * Math::PI / 180.0
      lambda = (l + 1.915 * Math.sin(g) + 0.020 * Math.sin(2 * g)) * Math::PI / 180.0
      epsilon = (23.439 - 0.0000004 * n) * Math::PI / 180.0
      ra = Math.atan2(Math.cos(epsilon) * Math.sin(lambda), Math.cos(lambda))
      dec = Math.asin(Math.sin(epsilon) * Math.sin(lambda))
      gmst = (280.46061837 + 360.98564736629 * (jd - 2_451_545.0)) % 360
      lst = (gmst + @lon) % 360
      ha = (lst - ra * 180.0 / Math::PI) % 360
      ha = ha - 360 if ha > 180
      ha_rad = ha * Math::PI / 180.0
      sin_alt = Math.sin(dec) * Math.sin(lat) + Math.cos(dec) * Math.cos(lat) * Math.cos(ha_rad)
      alt = Math.asin(sin_alt) * 180.0 / Math::PI
      alt < -6.0
    end

    def self.compass_label(degrees)
      return nil if degrees.nil?

      index = ((degrees.to_f % 360) + 11.25) / 22.5
      COMPASS[index.floor % 16]
    end
  end
end
