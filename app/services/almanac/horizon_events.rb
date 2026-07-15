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

    private

    def find_horizon_crossing(day_start, day_end, body, horizon_alt, direction)
      prev_alt = nil
      prev_time = nil

      samples = 288
      interval = (day_end - day_start) / samples.to_f

      (0..samples).each do |i|
        current_time = day_start + (i * interval)
        jd = datetime_to_julian_date(current_time)

        pos = @bsp_positions.position_for(body, jd)
        current_alt = pos[:altitude]

        if prev_alt && prev_time
          if direction == :rising && prev_alt < horizon_alt && current_alt >= horizon_alt
            fraction = (horizon_alt - prev_alt) / (current_alt - prev_alt)
            return prev_time + (fraction * (current_time - prev_time))
          elsif direction == :setting && prev_alt >= horizon_alt && current_alt < horizon_alt
            fraction = (prev_alt - horizon_alt) / (prev_alt - current_alt)
            return prev_time + (fraction * (current_time - prev_time))
          end
        end

        prev_alt = current_alt
        prev_time = current_time
      end

      nil
    end

    def find_transit(day_start, day_end, body)
      max_altitude = -999.0
      transit_time = nil

      samples = 288
      interval = (day_end - day_start) / samples.to_f

      (0..samples).each do |i|
        current_time = day_start + (i * interval)
        jd = datetime_to_julian_date(current_time)

        pos = @bsp_positions.position_for(body, jd)

        if pos[:altitude] > max_altitude
          max_altitude = pos[:altitude]
          transit_time = current_time
        end
      end

      transit_time
    end
  end
end
