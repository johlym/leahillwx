# frozen_string_literal: true

# Renders a 180° sky arc showing the sun's (and, if it's also up
# during the same window, the moon's) path across the sky today.
# Sunrise/moonrise sits at the left horizon (0°), midday transit at
# the top of the arc, sunset/moonset at the right (180°). A small
# glyph rides each arc at the current moment so you can see where
# each body actually is in the sky right now.
#
#   render Elements::SkyArcComponent.new(almanac: entry, now: Time.current)
module Elements
  class SkyArcComponent < ViewComponent::Base
    def initialize(almanac:, now: Time.current)
      @almanac = almanac
      # Always evaluate progress against the site timezone so UTC
      # servers don't treat "tomorrow" as already started mid-evening.
      @now = now.in_time_zone(zone)
      @uid = SecureRandom.hex(4)
    end

    def render?
      sun_rise_at && sun_set_at
    end

    def sun_progress
      progress(sun_rise_at, sun_set_at)
    end

    def moon_progress
      return nil unless moon_rise_at && moon_set_at
      progress(moon_rise_at, moon_set_at)
    end

    def sun_up?
      @now.between?(sun_rise_at, sun_set_at)
    end

    def moon_up?
      return false unless moon_rise_at && moon_set_at
      @now.between?(moon_rise_at, moon_set_at)
    end

    def sun_rise_label
      format_hm(sun_rise_at)
    end

    def sun_set_label
      format_hm(sun_set_at)
    end

    def sun_transit_label
      format_hm(almanac.solar_noon_at)
    end

    def moon_rise_label
      moon_rise_at && format_hm(moon_rise_at)
    end

    def moon_set_label
      moon_set_at && format_hm(moon_set_at)
    end

    def moon_transit_label
      almanac.moon_transit_at && format_hm(almanac.moon_transit_at)
    end

    def moon_phase_glyph
      case almanac.moon_phase.to_s.downcase
      when "new_moon", "new moon" then "fa-moon"
      when "waxing_crescent", "waxing crescent" then "fa-moon"
      when "first_quarter", "first quarter" then "fa-moon"
      when "waxing_gibbous", "waxing gibbous" then "fa-moon"
      when "full_moon", "full moon" then "fa-moon"
      when "waning_gibbous", "waning gibbous" then "fa-moon"
      when "last_quarter", "last quarter", "third_quarter", "third quarter" then "fa-moon"
      when "waning_crescent", "waning crescent" then "fa-moon"
      else "fa-moon"
      end
    end

    private

    attr_reader :almanac, :uid

    def zone
      almanac&.timezone.presence || "America/Los_Angeles"
    end

    def sun_rise_at
      almanac&.sunrise_at&.in_time_zone(zone)
    end

    def sun_set_at
      almanac&.sunset_at&.in_time_zone(zone)
    end

    def moon_rise_at
      almanac&.moonrise_at&.in_time_zone(zone)
    end

    def moon_set_at
      almanac&.moonset_at&.in_time_zone(zone)
    end

    # Returns a value in [0, 1] representing how far through the arc
    # `now` sits between rise and set. Clamped so bodies below the
    # horizon just park at 0.0 or 1.0 and stay visible as anchors.
    def progress(rise_at, set_at)
      return 0.0 if @now < rise_at
      return 1.0 if @now > set_at
      span = (set_at - rise_at).to_f
      return 0.5 if span <= 0
      ((@now - rise_at).to_f / span).clamp(0.0, 1.0)
    end

    def format_hm(t)
      return nil unless t
      t.in_time_zone(zone).strftime("%I:%M %p")
    end
  end
end
