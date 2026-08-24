# frozen_string_literal: true

module Almanac
  # Computes which naked-eye planets (Mercury–Saturn) are above the horizon
  # during civil night, with rise/set and a representative viewing direction.
  class PlanetNightGenerator
    include MathHelpers

    PLANET_LABELS = {
      mercury: "Mercury",
      venus: "Venus",
      mars: "Mars",
      jupiter: "Jupiter",
      saturn: "Saturn"
    }.freeze

    COMPASS = %w[
      N NNE NE ENE E ESE SE SSE
      S SSW SW WSW W WNW NW NNW
    ].freeze

    SAMPLE_MINUTES = 20

    def initialize(
      lat: ENV.fetch("LOCATION_LAT").to_f,
      lon: ENV.fetch("LOCATION_LON").to_f,
      timezone: "America/Los_Angeles"
    )
      @lat = lat
      @lon = lon
      @timezone = timezone
      @spk = EphemerisLoader.instance.spk
      @bsp = BspPositions.new(spk: @spk, lat: @lat, lon: @lon)
      @horizon = HorizonEvents.new(bsp_positions: @bsp)
    end

    def generate(date = Time.current.in_time_zone(@timezone).to_date)
      zone = ActiveSupport::TimeZone[@timezone]
      day_start = zone.local(date.year, date.month, date.day)
      day_end = day_start + 1.day
      next_day_end = day_end + 1.day

      civil_dusk = @horizon.civil_dusk(day_start, day_end) || day_start + 18.hours
      civil_dawn = @horizon.civil_dawn(day_end, next_day_end) || day_end + 6.hours

      planets = BspPositions::NAKED_EYE_PLANETS.map do |body|
        build_planet(body, day_start, next_day_end, civil_dusk, civil_dawn)
      end

      {
        date: date,
        timezone: @timezone,
        planets: planets
      }
    end

    def generate_and_persist!(date = Time.current.in_time_zone(@timezone).to_date)
      payload = generate(date)
      persist_payload!(payload)
    end

    private

    # Homepage traffic can enqueue multiple jobs for the same date before the first
    # insert commits; upsert on the unique date index keeps that race idempotent.
    def persist_payload!(payload)
      PlanetNight.upsert(
        {
          date: payload[:date],
          timezone: payload[:timezone],
          planets: payload[:planets]
        },
        unique_by: :index_planet_nights_on_date,
        update_only: %i[timezone planets]
      )
      PlanetNight.find_by!(date: payload[:date])
    end

    def build_planet(body, window_start, window_end, civil_dusk, civil_dawn)
      interval = night_interval(body, window_start, window_end, civil_dusk, civil_dawn)
      rise_at = interval && interval[0]
      set_at = interval && interval[1]
      visible = interval.present?

      transit_window_start = rise_at || civil_dusk
      transit_window_end = set_at || civil_dawn
      transit_at = @horizon.transit(body, transit_window_start, transit_window_end)

      samples = sample_path(body, rise_at, set_at)
      direction_az = direction_azimuth(body, rise_at, set_at, transit_at, civil_dusk)

      {
        "key" => body.to_s,
        "label" => PLANET_LABELS[body],
        "rise_at" => rise_at&.iso8601,
        "set_at" => set_at&.iso8601,
        "transit_at" => transit_at&.iso8601,
        "direction" => compass_label(direction_az),
        "direction_az" => direction_az&.round(1),
        "visible_tonight" => visible,
        "samples" => samples
      }
    end

    # Pair every rise with the following set, then pick the apparition that
    # overlaps civil night. Taking the first rise and first set independently
    # from local midnight treats last night's set and tonight's rise as one
    # interval, so morning planets and already-up outer planets never qualify.
    def night_interval(body, window_start, window_end, civil_dusk, civil_dawn)
      crossings = @horizon.horizon_crossings(body, window_start, window_end)
      up_at_start = altitude_at(body, window_start) >= 0.0
      above_horizon_intervals(crossings, up_at_start, window_start, window_end).find do |rise_at, set_at|
        visible_during_civil_night?(rise_at, set_at, civil_dusk, civil_dawn)
      end
    end

    def above_horizon_intervals(crossings, up_at_start, window_start, window_end)
      intervals = []
      current_start = up_at_start ? window_start : nil

      crossings.each do |crossing|
        if crossing[:direction] == :rising
          current_start = crossing[:time]
        elsif crossing[:direction] == :setting && current_start
          intervals << [ current_start, crossing[:time] ]
          current_start = nil
        end
      end

      intervals << [ current_start, window_end ] if current_start
      intervals
    end

    def altitude_at(body, time)
      @bsp.position_for(body, datetime_to_julian_date(time))[:altitude]
    end

    def sample_path(body, rise_at, set_at)
      return [] unless rise_at && set_at && set_at > rise_at

      samples = []
      t = rise_at
      while t <= set_at
        jd = datetime_to_julian_date(t)
        pos = @bsp.position_for(body, jd)
        samples << {
          "at" => t.iso8601,
          "az_deg" => pos[:azimuth].round(2),
          "alt_deg" => pos[:altitude].round(2)
        }
        t += SAMPLE_MINUTES.minutes
      end

      # Ensure set sample is included.
      if samples.last.nil? || Time.iso8601(samples.last["at"]) < set_at - 1.minute
        jd = datetime_to_julian_date(set_at)
        pos = @bsp.position_for(body, jd)
        samples << {
          "at" => set_at.iso8601,
          "az_deg" => pos[:azimuth].round(2),
          "alt_deg" => pos[:altitude].round(2)
        }
      end

      samples
    end

    def visible_during_civil_night?(rise_at, set_at, civil_dusk, civil_dawn)
      return false unless rise_at && set_at

      # Overlap between [rise, set] and [civil_dusk, civil_dawn].
      overlap_start = [ rise_at, civil_dusk ].max
      overlap_end = [ set_at, civil_dawn ].min
      overlap_end > overlap_start
    end

    def direction_azimuth(body, rise_at, set_at, transit_at, civil_dusk)
      now = Time.current
      if rise_at && set_at && now.between?(rise_at, set_at)
        return @bsp.position_for(body, datetime_to_julian_date(now))[:azimuth]
      end

      if transit_at && civil_dusk && transit_at >= civil_dusk
        return @bsp.position_for(body, datetime_to_julian_date(transit_at))[:azimuth]
      end

      t = [ rise_at, civil_dusk ].compact.max
      return nil unless t

      @bsp.position_for(body, datetime_to_julian_date(t))[:azimuth]
    end

    def compass_label(degrees)
      return nil if degrees.nil?

      index = ((degrees.to_f % 360) + 11.25) / 22.5
      COMPASS[index.floor % 16]
    end
  end
end
