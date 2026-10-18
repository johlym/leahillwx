# frozen_string_literal: true

require "test_helper"

class Almanac::HorizonEventsTest < ActiveSupport::TestCase
  test "horizon_crossings returns every rise and set in a multi-day window" do
    tz = ActiveSupport::TimeZone["UTC"]
    day_start = tz.parse("2026-08-24 00:00:00")
    day_end = day_start + 2.days
    events = Almanac::HorizonEvents.new(bsp_positions: SquareWavePositions.new)

    crossings = events.horizon_crossings(:saturn, day_start, day_end)

    assert_equal %i[rising setting rising setting], crossings.map { |c| c[:direction] }
    assert_equal 4, crossings.size
    assert crossings.each_cons(2).all? { |a, b| a[:time] < b[:time] }
  end

  test "rise and set still return the first crossing of each direction" do
    tz = ActiveSupport::TimeZone["UTC"]
    day_start = tz.parse("2026-08-24 00:00:00")
    day_end = day_start + 2.days
    events = Almanac::HorizonEvents.new(bsp_positions: SquareWavePositions.new)

    rise = events.rise(:saturn, day_start, day_end)
    set_at = events.set(:saturn, day_start, day_end)

    assert_not_nil rise
    assert_not_nil set_at
    assert rise < set_at
    assert_in_delta 6.0, rise.hour + (rise.min / 60.0), 0.2
    assert_in_delta 18.0, set_at.hour + (set_at.min / 60.0), 0.2
  end

  # +10° from 06:00–18:00 UTC, -10° otherwise. Crossings land on those hours.
  class SquareWavePositions
    def position_for(_body, jd)
      time = Time.at((jd - 2440587.5) * 86400.0).utc
      minutes = (time.hour * 60) + time.min
      up = minutes >= (6 * 60) && minutes < (18 * 60)
      { altitude: up ? 10.0 : -10.0, azimuth: 180.0 }
    end
  end
end
