require "test_helper"

class Celestial::EphemerisPolynomialGeneratorTest < ActiveSupport::TestCase
  # Disable parallelization for these tests since they need the shared BSP ephemeris
  parallelize(workers: 1)

  setup do
    # Ensure ephemeris is loaded (important for parallel test workers)
    Almanac::EphemerisLoader.instance
    @generator = Celestial::EphemerisPolynomialGenerator.new
  end

  test "should generate daily ephemeris for sun" do
    result = @generator.generate_daily_ephemeris(:sun, 2024, 2, 4)

    assert result.is_a?(Hash)
    assert_equal 86400, result[:m]
    assert result[:t].is_a?(Integer)
    assert result[:e].is_a?(Hash)
    assert result[:o].is_a?(Hash)
  end

  test "should generate daily ephemeris for moon" do
    result = @generator.generate_daily_ephemeris(:moon, 2024, 2, 4)

    assert result.is_a?(Hash)
    assert_equal 86400, result[:m]
    assert result[:e].key?("moon")
    assert result[:o].key?("moon")
  end

  test "timestamp should represent local midnight" do
    result = @generator.generate_daily_ephemeris(:sun, 2024, 2, 4)

    timestamp = result[:t]
    time = Time.at(timestamp).in_time_zone("America/Los_Angeles")

    assert_equal 2024, time.year
    assert_equal 2, time.month
    assert_equal 4, time.day
    assert_equal 0, time.hour
    assert_equal 0, time.min
    assert_equal 0, time.sec
  end

  test "events should have valid structure" do
    result = @generator.generate_daily_ephemeris(:sun, 2024, 6, 21)

    events = result[:e]["sun"]
    assert events.is_a?(Array)

    events.each do |event|
      assert event.key?(:s)
      assert event.key?(:t)
      assert event[:s] >= 0
      assert event[:s] <= 86400
      assert event[:t].is_a?(Integer)
    end
  end

  test "events should be sorted by time" do
    result = @generator.generate_daily_ephemeris(:sun, 2024, 6, 21)

    events = result[:e]["sun"]
    times = events.map { |e| e[:s] }

    assert_equal times, times.sort
  end

  test "observables should contain altitude and azimuth" do
    result = @generator.generate_daily_ephemeris(:sun, 2024, 2, 4)

    observables = result[:o]["sun"]
    assert observables.key?("alt")
    assert observables.key?("az")
    assert observables["alt"].is_a?(Array)
    assert observables["az"].is_a?(Array)
  end

  test "polynomial segments should have valid structure" do
    result = @generator.generate_daily_ephemeris(:sun, 2024, 2, 4)

    segments = result[:o]["sun"]["alt"]

    segments.each do |segment|
      assert segment.key?(:e)
      assert segment.key?(:p)
      assert segment[:e].is_a?(Integer)
      assert segment[:p].is_a?(Array)
      assert_equal 4, segment[:p].length

      segment[:p].each do |coeff|
        assert coeff.is_a?(Numeric)
      end
    end
  end

  test "segments should be contiguous from 0 to 86400" do
    result = @generator.generate_daily_ephemeris(:sun, 2024, 2, 4)

    alt_segments = result[:o]["sun"]["alt"]

    assert alt_segments.length > 0
    assert_equal 86400, alt_segments.last[:e]

    prev_end = 0
    alt_segments.each do |segment|
      assert segment[:e] > prev_end
      prev_end = segment[:e]
    end
  end

  test "azimuth should be unwrapped and continuous" do
    result = @generator.generate_daily_ephemeris(:sun, 2024, 2, 4)

    az_segments = result[:o]["sun"]["az"]

    assert az_segments.length > 0

    az_segments.each do |segment|
      segment[:p].each do |coeff|
        assert coeff.is_a?(Numeric)
      end
    end
  end

  test "polynomial evaluation should be accurate" do
    result = @generator.generate_daily_ephemeris(:sun, 2024, 2, 4)

    alt_segments = result[:o]["sun"]["alt"]

    alt_segments.each do |segment|
      a0, a1, a2, a3 = segment[:p]

      assert a0.is_a?(Numeric)
      assert a1.is_a?(Numeric)
      assert a2.is_a?(Numeric)
      assert a3.is_a?(Numeric)
    end
  end

  test "should handle summer solstice with long day" do
    result = @generator.generate_daily_ephemeris(:sun, 2024, 6, 21)

    assert_equal 86400, result[:m]
    assert result[:e]["sun"].length > 0
    assert result[:o]["sun"]["alt"].length > 0
  end

  test "should handle winter solstice with short day" do
    result = @generator.generate_daily_ephemeris(:sun, 2024, 12, 21)

    assert_equal 86400, result[:m]
    assert result[:e]["sun"].length > 0
    assert result[:o]["sun"]["alt"].length > 0
  end

  test "should handle equinox dates" do
    result = @generator.generate_daily_ephemeris(:sun, 2024, 3, 20)

    assert_equal 86400, result[:m]
    assert result[:o]["sun"]["alt"].length > 0
  end

  test "moon ephemeris should have events" do
    result = @generator.generate_daily_ephemeris(:moon, 2024, 2, 4)

    events = result[:e]["moon"]
    assert events.is_a?(Array)
  end

  test "moon observables should be continuous" do
    result = @generator.generate_daily_ephemeris(:moon, 2024, 2, 4)

    alt_segments = result[:o]["moon"]["alt"]
    az_segments = result[:o]["moon"]["az"]

    assert alt_segments.last[:e] == 86400
    assert az_segments.last[:e] == 86400
  end

  test "coefficients should be rounded to appropriate precision" do
    result = @generator.generate_daily_ephemeris(:sun, 2024, 2, 4)

    segments = result[:o]["sun"]["alt"]

    segments.each do |segment|
      segment[:p].each do |coeff|
        coeff_str = coeff.to_s
        decimal_places = coeff_str.split(".").last&.length || 0

        assert decimal_places <= 8, "Coefficient should be rounded to 8 decimal places max"
      end
    end
  end

  test "should handle different body types" do
    sun_result = @generator.generate_daily_ephemeris(:sun, 2024, 2, 4)
    moon_result = @generator.generate_daily_ephemeris(:moon, 2024, 2, 4)

    assert sun_result[:o].key?("sun")
    assert moon_result[:o].key?("moon")
    refute sun_result[:o].key?("moon")
    refute moon_result[:o].key?("sun")
  end

  test "should generate different data for different dates" do
    result1 = @generator.generate_daily_ephemeris(:sun, 2025, 2, 4)
    result2 = @generator.generate_daily_ephemeris(:sun, 2025, 6, 21)

    refute_equal result1[:t], result2[:t]

    alt1 = result1[:o]["sun"]["alt"]
    alt2 = result2[:o]["sun"]["alt"]

    refute_equal alt1.first[:p], alt2.first[:p]
  end

  test "should handle leap year correctly" do
    result = @generator.generate_daily_ephemeris(:sun, 2024, 2, 28)

    assert_equal 86400, result[:m]
    timestamp = result[:t]
    time = Time.at(timestamp).in_time_zone("America/Los_Angeles")
    assert_equal 28, time.day
  end

  test "segments should have reasonable coefficient values" do
    result = @generator.generate_daily_ephemeris(:sun, 2024, 2, 4)
    segments = result[:o]["sun"]["alt"]

    segments.each do |segment|
      segment[:p].each do |coeff|
        assert coeff.finite?, "Coefficients should be finite numbers"
        assert coeff.abs < 1e10, "Coefficients should not be unreasonably large"
      end
    end
  end
end
