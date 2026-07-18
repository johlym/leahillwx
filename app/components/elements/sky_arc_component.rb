# frozen_string_literal: true

# Renders a sky dome with one or more body arcs.
#
# Each body rides a fixed semicircle from rise (left, 0°) to set (right, 180°).
# Before rise the glyph parks at 0°; after set it parks at 180°; in between it
# sits at time-progress along that same arc.
#
#   Elements::SkyArcComponent.new(bodies: [
#     { key: "venus", label: "Venus", rise_at:, set_at:, color: "..." }
#   ])
#
# Back-compat — AlmanacEntry sun/moon:
#   Elements::SkyArcComponent.new(almanac: entry)
module Elements
  class SkyArcComponent < ViewComponent::Base
    Body = Data.define(:key, :label, :rise_at, :set_at, :color, :radius, :glyph_r) do
      def initialize(key:, label:, rise_at: nil, set_at: nil, color: nil, radius: 90, glyph_r: 5)
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

    # SVG arc from left horizon → right horizon at the body's radius.
    def arc_d(body)
      r = body.radius
      left_x = (100 - r).round(2)
      right_x = (100 + r).round(2)
      "M #{left_x} 100 A #{r} #{r} 0 0 1 #{right_x} 100"
    end

    def current_point(body)
      theta = progress_for(body) * Math::PI
      {
        x: (100 - Math.cos(theta) * body.radius).round(2),
        y: (100 - Math.sin(theta) * body.radius).round(2)
      }
    end

    def progress_for(body)
      return 0.0 if @now < body.rise_at
      return 1.0 if @now > body.set_at

      span = (body.set_at - body.rise_at).to_f
      return 0.5 if span <= 0

      ((@now - body.rise_at).to_f / span).clamp(0.0, 1.0)
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
          set_at: almanac.sunset_at
        ),
        build_body(
          key: "moon",
          label: "Moon",
          rise_at: almanac.moonrise_at,
          set_at: almanac.moonset_at
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
  end
end
