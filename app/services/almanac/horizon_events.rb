module Almanac
  class HorizonEvents
    include MathHelpers

    SUNRISE_HORIZON_ALT = -35.0 / 60.0
    CIVIL_TWILIGHT_ALT = -6.0
    NAUTICAL_TWILIGHT_ALT = -12.0
    ASTRONOMICAL_TWILIGHT_ALT = -18.0
    MOONRISE_HORIZON_ALT = -49.0 / 60.0

    def initialize(bsp_positions:)
      @bsp_positions = bsp_positions
    end

    def sun_rise(day_start, day_end)
      find_horizon_crossing(day_start, day_end, :sun, SUNRISE_HORIZON_ALT, :rising)
    end

    def sun_set(day_start, day_end)
      find_horizon_crossing(day_start, day_end, :sun, SUNRISE_HORIZON_ALT, :setting)
    end

    def sun_transit(day_start, day_end)
      find_transit(day_start, day_end, :sun)
    end

    def civil_dawn(day_start, day_end)
      find_horizon_crossing(day_start, day_end, :sun, CIVIL_TWILIGHT_ALT, :rising)
    end

    def civil_dusk(day_start, day_end)
      find_horizon_crossing(day_start, day_end, :sun, CIVIL_TWILIGHT_ALT, :setting)
    end

    def nautical_dawn(day_start, day_end)
      find_horizon_crossing(day_start, day_end, :sun, NAUTICAL_TWILIGHT_ALT, :rising)
    end

    def nautical_dusk(day_start, day_end)
      find_horizon_crossing(day_start, day_end, :sun, NAUTICAL_TWILIGHT_ALT, :setting)
    end

    def astronomical_dawn(day_start, day_end)
      find_horizon_crossing(day_start, day_end, :sun, ASTRONOMICAL_TWILIGHT_ALT, :rising)
    end

    def astronomical_dusk(day_start, day_end)
      find_horizon_crossing(day_start, day_end, :sun, ASTRONOMICAL_TWILIGHT_ALT, :setting)
    end

    def moon_rise(day_start, day_end)
      find_horizon_crossing(day_start, day_end, :moon, MOONRISE_HORIZON_ALT, :rising)
    end

    def moon_set(day_start, day_end)
      find_horizon_crossing(day_start, day_end, :moon, MOONRISE_HORIZON_ALT, :setting)
    end

    def moon_transit(day_start, day_end)
      find_transit(day_start, day_end, :moon)
    end

    # Generic rise/set/transit for any body supported by BspPositions.
    def rise(body, day_start, day_end, horizon_alt: 0.0)
      find_horizon_crossing(day_start, day_end, body, horizon_alt, :rising)
    end

    def set(body, day_start, day_end, horizon_alt: 0.0)
      find_horizon_crossing(day_start, day_end, body, horizon_alt, :setting)
    end

    def transit(body, day_start, day_end)
      find_transit(day_start, day_end, body)
    end

    # All rising/setting crossings in chronological order. Needed to pair a
    # body's above-horizon intervals — first-rise + first-set in a midnight
    # window are not the same apparition for morning or already-up planets.
    def horizon_crossings(body, day_start, day_end, horizon_alt: 0.0)
      crossings = []
      prev_alt = nil
      prev_time = nil

      each_sampled_altitude(day_start, day_end, body) do |current_time, current_alt|
        if prev_alt && prev_time
          crossing = interpolated_crossing(prev_time, prev_alt, current_time, current_alt, horizon_alt)
          crossings << crossing if crossing
        end

        prev_alt = current_alt
        prev_time = current_time
      end

      crossings
    end

    private

    def find_horizon_crossing(day_start, day_end, body, horizon_alt, direction)
      horizon_crossings(body, day_start, day_end, horizon_alt: horizon_alt)
        .find { |crossing| crossing[:direction] == direction }
        &.fetch(:time)
    end

    def interpolated_crossing(prev_time, prev_alt, current_time, current_alt, horizon_alt)
      if prev_alt < horizon_alt && current_alt >= horizon_alt
        fraction = (horizon_alt - prev_alt) / (current_alt - prev_alt)
        { time: prev_time + (fraction * (current_time - prev_time)), direction: :rising }
      elsif prev_alt >= horizon_alt && current_alt < horizon_alt
        fraction = (prev_alt - horizon_alt) / (prev_alt - current_alt)
        { time: prev_time + (fraction * (current_time - prev_time)), direction: :setting }
      end
    end

    def each_sampled_altitude(day_start, day_end, body)
      samples = sample_count(day_start, day_end)
      interval = (day_end - day_start) / samples.to_f

      (0..samples).each do |i|
        current_time = day_start + (i * interval)
        jd = datetime_to_julian_date(current_time)
        yield current_time, @bsp_positions.position_for(body, jd)[:altitude]
      end
    end

    # ~5 minute samples. A 24h window stays at the historical 288-sample cadence
    # so sun/moon almanac times do not shift.
    def sample_count(day_start, day_end)
      span_minutes = (day_end - day_start) / 60.0
      [ (span_minutes / 5.0).ceil, 96 ].max
    end

    def find_transit(day_start, day_end, body)
      max_altitude = -999.0
      transit_time = nil

      each_sampled_altitude(day_start, day_end, body) do |current_time, current_alt|
        if current_alt > max_altitude
          max_altitude = current_alt
          transit_time = current_time
        end
      end

      transit_time
    end
  end
end
