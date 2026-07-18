# frozen_string_literal: true

require "test_helper"

class Iss::TleTest < ActiveSupport::TestCase
  SAMPLE = <<~TLE
    ISS (ZARYA)
    1 25544U 98067A   24182.52469136  .00016717  00000+0  30728-3 0  9993
    2 25544  51.6404 249.2102 0005323  50.9433 309.2107 15.49676387462695
  TLE

  test "parses name and orbital elements" do
    tle = Iss::Tle.parse(SAMPLE)
    assert_equal "25544", tle.satnum
    assert_equal "ISS (ZARYA)", tle.name
    assert_in_delta 51.6404, tle.inclination_deg, 0.0001
    assert_in_delta 15.49676387, tle.mean_motion, 0.0000001
    assert tle.epoch.utc?
  end

  test "sgp4 returns TEME meters and mps" do
    tle = Iss::Tle.parse(SAMPLE)
    state = Iss::Sgp4.new(tle).propagate(tle.epoch + 10.minutes)
    assert_equal 3, state[:position_m].size
    assert_equal 3, state[:velocity_mps].size
    # ISS altitude roughly 400km → radius ~6770km
    r = Math.sqrt(state[:position_m].sum { |c| c**2 })
    assert r.between?(6_500_000, 7_200_000)
  end
end
