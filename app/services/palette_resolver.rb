# frozen_string_literal: true

# Resolves which time-of-day palette should be active for a given moment
# using today's astronomical almanac. Boundaries (all in the almanac's
# timezone, which is America/Los_Angeles for this app):
#
#   sunrise            -> :sunrise
#   1:00 local        -> :midday
#   sunset - 1 hour    -> :sunset
#   sunset + 10 min    -> :night
#
# Also exposes the next boundary transition so the client can schedule
# a single timer rather than polling.
class PaletteResolver
  PALETTES = %i[sunrise midday sunset night].freeze

  # @param almanac [AlmanacEntry] the entry for the day containing `at`.
  # @param at [Time, nil] the moment to evaluate; defaults to now.
  # @param fallback [Symbol] palette to use when the almanac is missing.
  def initialize(almanac:, at: Time.current, fallback: :night)
    @almanac = almanac
    @at = at
    @fallback = fallback
  end

  # @return [Symbol] one of PALETTES.
  def palette
    return @fallback unless almanac_usable?

    if @at < sunrise
      :night
    elsif @at < noon_window_start
      :sunrise
    elsif @at < sunset_window_start
      :midday
    elsif @at < sunset_window_end
      :sunset
    else
      :night
    end
  end

  # Timestamp when the current palette would flip to the next one,
  # or nil if we can't compute it (missing almanac).
  # @return [Time, nil]
  def next_transition_at
    return nil unless almanac_usable?

    boundaries = [ sunrise, noon_window_start, sunset_window_start, sunset_window_end ]
    upcoming = boundaries.find { |b| b > @at }
    upcoming || next_day_first_boundary
  end

  private

  attr_reader :almanac, :at

  def almanac_usable?
    almanac.present? && almanac.sunrise_at.present? && almanac.sunset_at.present?
  end

  def zone
    almanac.timezone.presence || "America/Los_Angeles"
  end

  def sunrise
    almanac.sunrise_at.in_time_zone(zone)
  end

  def sunset
    almanac.sunset_at.in_time_zone(zone)
  end

  def noon_window_start
    day = sunrise.to_date
    Time.use_zone(zone) { Time.zone.local(day.year, day.month, day.day, 10, 0, 0) }
  end

  def sunset_window_start
    sunset - 1.hour
  end

  def sunset_window_end
    sunset + 30.minutes
  end

  # If all of today's boundaries have passed, we approximate the next
  # transition as tomorrow's sunrise using a naive +24h shift. The
  # controller will re-resolve on load anyway, so this is a safe
  # scheduling floor rather than an authoritative value.
  def next_day_first_boundary
    sunrise + 1.day
  end
end
