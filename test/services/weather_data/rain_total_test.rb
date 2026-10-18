# frozen_string_literal: true

require "test_helper"

class WeatherData::RainTotalTest < ActiveSupport::TestCase
  Reading = Struct.new(:reading_date_time, :rain_day)

  setup do
    @zone = Time.find_zone!("America/Los_Angeles")
  end

  test "daily total is the counter at the last reading, not the peak" do
    # 5.842 mm is 0.23 inches — a spike the homepage no longer shows.
    readings = [
      at(0, 10, 0.0),
      at(1, 0, 5.842),
      at(1, 5, 0.0),
      at(15, 0, 0.0)
    ]

    result = WeatherData::RainTotal.attribute(readings)

    assert_in_delta 0.0, result.total_mm, 0.001
    assert_in_delta 0.0, result.hourly_mm.values.sum, 0.001
  end

  test "midnight carryover from yesterday is not today's rain" do
    baseline = at(23, 50, 5.842, day: 14)
    readings = [
      at(0, 2, 5.842),
      at(0, 6, 0.0),
      at(12, 0, 0.0)
    ]

    result = WeatherData::RainTotal.attribute(readings, baseline: baseline)

    assert_in_delta 0.0, result.total_mm, 0.001
    assert_in_delta 0.0, result.hourly_mm[0].to_f, 0.001
  end

  test "rain after a midnight reset is kept" do
    baseline = at(23, 50, 5.842, day: 14)
    readings = [
      at(0, 2, 5.842),
      at(0, 6, 0.0),
      at(2, 0, 2.54),
      at(15, 30, 5.08)
    ]

    result = WeatherData::RainTotal.attribute(readings, baseline: baseline)

    assert_in_delta 5.08, result.total_mm, 0.001
    assert_in_delta 2.54, result.hourly_mm[2], 0.001
    assert_in_delta 2.54, result.hourly_mm[15], 0.001
    assert_in_delta 5.08, result.hourly_mm.values.sum, 0.001
  end

  test "a spike that recovers inside one hour does not count" do
    baseline = at(8, 50, 0.0)
    readings = [
      at(9, 5, 0.0),
      at(9, 10, 5.842),
      at(9, 40, 0.0)
    ]

    result = WeatherData::RainTotal.attribute(readings, baseline: baseline)

    assert_in_delta 0.0, result.total_mm, 0.001
    assert_in_delta 0.0, result.hourly_mm[9].to_f, 0.001
  end

  test "a spike corrected in a later hour is removed from the earlier hour" do
    readings = [
      at(1, 10, 0.0),
      at(1, 40, 5.842),
      at(3, 5, 0.0),
      at(3, 30, 1.27)
    ]

    result = WeatherData::RainTotal.attribute(readings)

    assert_in_delta 1.27, result.total_mm, 0.001
    assert_in_delta 0.0, result.hourly_mm[1].to_f, 0.001
    assert_in_delta 1.27, result.hourly_mm[3], 0.001
  end

  test "monotonic counter matches the last reading and splits by hour" do
    baseline = at(23, 0, 0.0, day: 14)
    readings = [
      at(0, 30, 0.0),
      at(4, 0, 1.27),
      at(4, 30, 2.54)
    ]

    result = WeatherData::RainTotal.attribute(readings, baseline: baseline)

    assert_in_delta 2.54, result.total_mm, 0.001
    assert_in_delta 2.54, result.hourly_mm[4], 0.001
  end

  test "an unreset counter still reports the station total" do
    baseline = at(23, 40, 5.842, day: 14)
    readings = [
      at(0, 10, 5.842),
      at(18, 0, 5.842)
    ]

    result = WeatherData::RainTotal.attribute(readings, baseline: baseline)

    assert_in_delta 5.842, result.total_mm, 0.001
    assert_in_delta 0.0, result.hourly_mm.values.sum, 0.001
  end

  private

  def at(hour, minute, rain_day, day: 15)
    Reading.new(@zone.local(2026, 6, day, hour, minute, 0), rain_day)
  end
end
