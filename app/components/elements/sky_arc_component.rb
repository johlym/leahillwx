# frozen_string_literal: true

# Renders a sky dome with one or more body paths.
#
# Preferred API — sampled alt/az paths:
#   Elements::SkyArcComponent.new(bodies: [
#     { key: "venus", label: "Venus", rise_at:, set_at:, samples: [...], color: "..." }
#   ])
#
# Back-compat — AlmanacEntry sun/moon:
#   Elements::SkyArcComponent.new(almanac: entry)
module Elements
  class SkyArcComponent < ViewComponent::Base
    Body = Data.define(:key, :label, :rise_at, :set_at, :samples, :color, :radius, :glyph_r) do
      def initialize(key:, label:, rise_at: nil, set_at: nil, samples: [], color: nil, radius: 90, glyph_r: 5)
        super
      end
    end

    DEFAULT_RADIUS = {
      "sun" => 90,
      "moon" => 78,
      "mercury" => 86,
      "venus" => 82,
      "mars" => 74,
      "jupiter" => 70,
      "saturn" => 66
    }.freeze

    DEFAULT_COLORS = {
      "sun" => "var(--color-warning)",
      "moon" => "color-mix(in oklab, var(--color-muted) 90%, transparent)",
      "mercury" => "color-mix(in oklab, var(--color-muted) 70%, var(--color-accent))",
      "venus" => "color-mix(in oklab, var(--color-warning) 55%, white)",
      "mars" => "color-mix(in oklab, var(--color-danger, #c44) 80%, var(--color-warning))",
      "jupiter" => "color-mix(in oklab, var(--color-accent) 70%, white)",
      "saturn" => "color-mix(in oklab, var(--color-accent-strong) 60%, var(--color-muted))"
    }.freeze

    def initialize(almanac: nil, bodies: nil, now: Time.current)
      @almanac = almanac
      @now = now.in_time_zone(zone)
      @uid = SecureRandom.hex(4)
      @bodies = normalize_bodies(bodies)
    end

    def render?
      @bodies.any? { |b| b.rise_at && b.set_at }
    end

    def bodies
      @bodies.select { |b| b.rise_at && b.set_at }
    end

    def path_points(body)
      if body.samples.present?
        body.samples.filter_map { |sample| project_sample(sample, body.radius) }
      else
        time_linear_points(body)
      end
    end

    def path_d(body)
      pts = path_points(body)
      return nil if pts.empty?

      commands = pts.each_with_index.map do |pt, i|
        "#{i.zero? ? 'M' : 'L'} #{pt[:x]} #{pt[:y]}"
      end
      commands.join(" ")
    end

    def current_point(body)
      if body.samples.present?
        sample = interpolate_sample(body)
        return project_alt_az(sample[:az], sample[:alt], body.radius) if sample
      end

      progress = progress_for(body)
      theta = progress * Math::PI
      {
        x: (100 - Math.cos(theta) * body.radius).round(2),
        y: (100 - Math.sin(theta) * body.radius).round(2)
      }
    end

    def up?(body)
      return false unless body.rise_at && body.set_at

      @now.between?(body.rise_at, body.set_at)
    end

    def format_hm(t)
      return nil unless t

      t.in_time_zone(zone).strftime("%I:%M %p")
    end

    attr_reader :uid

    private

    attr_reader :almanac

    def zone
      almanac&.timezone.presence || "America/Los_Angeles"
    end

    def normalize_bodies(bodies)
      if bodies.present?
        return Array(bodies).map { |b| build_body(b) }
      end

      return [] unless almanac

      [
        build_body(
          key: "sun",
          label: "Sun",
          rise_at: almanac.sunrise_at,
          set_at: almanac.sunset_at,
          samples: hourly_samples(almanac.sun_positions_hourly)
        ),
        build_body(
          key: "moon",
          label: "Moon",
          rise_at: almanac.moonrise_at,
          set_at: almanac.moonset_at,
          samples: hourly_samples(almanac.moon_positions_hourly)
        )
      ]
    end

    def build_body(hash)
      h = hash.respond_to?(:with_indifferent_access) ? hash.with_indifferent_access : hash.to_h.with_indifferent_access
      key = h[:key].to_s
      Body.new(
        key: key,
        label: h[:label] || key.titleize,
        rise_at: cast_time(h[:rise_at]),
        set_at: cast_time(h[:set_at]),
        samples: Array(h[:samples]),
        color: h[:color] || DEFAULT_COLORS[key] || "var(--color-accent)",
        radius: (h[:radius] || DEFAULT_RADIUS[key] || 72).to_f,
        glyph_r: (h[:glyph_r] || (key == "sun" ? 7 : 5)).to_f
      )
    end

    def cast_time(value)
      case value
      when nil then nil
      when Time, ActiveSupport::TimeWithZone then value.in_time_zone(zone)
      else Time.zone.parse(value.to_s)&.in_time_zone(zone)
      end
    end

    def hourly_samples(payload)
      return [] if payload.blank?

      # Almanac hourly JSON varies; accept [{t/at, az/azimuth, alt/altitude}, ...]
      # or a hash keyed by hour.
      list = payload.is_a?(Hash) ? payload.values : Array(payload)
      list.filter_map do |entry|
        e = entry.with_indifferent_access
        az = e[:az_deg] || e[:azimuth] || e[:az]
        alt = e[:alt_deg] || e[:altitude] || e[:alt]
        at = e[:at] || e[:t] || e[:time]
        next if az.nil? || alt.nil?

        { "at" => at, "az_deg" => az.to_f, "alt_deg" => alt.to_f }
      end
    end

    def progress_for(body)
      return 0.0 if @now < body.rise_at
      return 1.0 if @now > body.set_at

      span = (body.set_at - body.rise_at).to_f
      return 0.5 if span <= 0

      ((@now - body.rise_at).to_f / span).clamp(0.0, 1.0)
    end

    def time_linear_points(body)
      (0..24).map do |i|
        progress = i / 24.0
        theta = progress * Math::PI
        {
          x: (100 - Math.cos(theta) * body.radius).round(2),
          y: (100 - Math.sin(theta) * body.radius).round(2)
        }
      end
    end

    def project_sample(sample, radius)
      s = sample.with_indifferent_access
      az = (s[:az_deg] || s[:azimuth] || s[:az]).to_f
      alt = (s[:alt_deg] || s[:altitude] || s[:alt]).to_f
      return nil if alt < -1

      project_alt_az(az, alt, radius)
    end

    # N-up zenith-distance projection onto the dome.
    def project_alt_az(az_deg, alt_deg, radius)
      clamped_alt = alt_deg.clamp(0.0, 90.0)
      r = ((90.0 - clamped_alt) / 90.0) * radius
      az = az_deg * Math::PI / 180.0
      {
        x: (100 + r * Math.sin(az)).round(2),
        y: (100 - r * Math.cos(az)).round(2)
      }
    end

    def interpolate_sample(body)
      stamped = body.samples.filter_map do |sample|
        s = sample.with_indifferent_access
        at = cast_time(s[:at])
        next unless at

        { at: at, az: (s[:az_deg] || s[:az]).to_f, alt: (s[:alt_deg] || s[:alt]).to_f }
      end.sort_by { |s| s[:at] }
      return nil if stamped.empty?

      return stamped.first.slice(:az, :alt) if @now <= stamped.first[:at]
      return stamped.last.slice(:az, :alt) if @now >= stamped.last[:at]

      stamped.each_cons(2) do |a, b|
        next unless @now.between?(a[:at], b[:at])

        span = (b[:at] - a[:at]).to_f
        t = span <= 0 ? 0.0 : (@now - a[:at]) / span
        return {
          az: a[:az] + (b[:az] - a[:az]) * t,
          alt: a[:alt] + (b[:alt] - a[:alt]) * t
        }
      end

      nil
    end
  end
end
