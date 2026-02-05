require "test_helper"

class Celestial::EphemerisServiceTest < ActiveSupport::TestCase
  # Disable parallelization for these tests since they need the shared BSP ephemeris
  parallelize(workers: 1)
  test "should generate ephemeris with explicit date params" do
    result = Celestial::EphemerisService.generate(:sun, year: 2024, month: 2, day: 4)

    assert result.is_a?(Hash)
    assert_equal 86400, result[:m]
    assert result[:t].is_a?(Integer)
    assert result[:e].is_a?(Hash)
    assert result[:o].is_a?(Hash)
  end

  test "should use current date when no params provided" do
    result = Celestial::EphemerisService.generate(:sun, {})

    assert result.is_a?(Hash)
    assert_equal 86400, result[:m]
  end

  test "should handle moon body type" do
    result = Celestial::EphemerisService.generate(:moon, year: 2024, month: 2, day: 4)

    assert result.is_a?(Hash)
    assert result[:e].key?("moon")
    assert result[:o].key?("moon")
  end

  test "should handle sun body type" do
    result = Celestial::EphemerisService.generate(:sun, year: 2024, month: 2, day: 4)

    assert result.is_a?(Hash)
    assert result[:e].key?("sun")
    assert result[:o].key?("sun")
  end

  test "should return error for invalid date" do
    result = Celestial::EphemerisService.generate(:sun, year: 2024, month: 13, day: 1)

    assert result.key?(:error)
    assert_match(/Invalid date/, result[:error])
  end

  test "should return error for invalid month" do
    result = Celestial::EphemerisService.generate(:sun, year: 2024, month: 0, day: 15)

    assert result.key?(:error)
    assert_match(/Invalid date/, result[:error])
  end

  test "should return error for invalid day" do
    result = Celestial::EphemerisService.generate(:sun, year: 2024, month: 2, day: 30)

    assert result.key?(:error)
    assert_match(/Invalid date/, result[:error])
  end

  test "should handle leap year dates" do
    result = Celestial::EphemerisService.generate(:sun, year: 2024, month: 2, day: 29)

    assert result.is_a?(Hash)
    assert_equal 86400, result[:m]
  end

  test "should reject invalid leap year dates" do
    result = Celestial::EphemerisService.generate(:sun, year: 2023, month: 2, day: 29)

    assert result.key?(:error)
    assert_match(/Invalid date/, result[:error])
  end

  test "should handle year boundary dates" do
    result = Celestial::EphemerisService.generate(:sun, year: 2024, month: 1, day: 1)
    assert_equal 86400, result[:m]

    result = Celestial::EphemerisService.generate(:sun, year: 2024, month: 12, day: 31)
    assert_equal 86400, result[:m]
  end

  test "should convert string params to integers" do
    result = Celestial::EphemerisService.generate(:sun, year: "2024", month: "2", day: "4")

    assert result.is_a?(Hash)
    assert_equal 86400, result[:m]
  end

  test "should handle nil params gracefully" do
    result = Celestial::EphemerisService.generate(:sun, year: nil, month: nil, day: nil)

    assert result.is_a?(Hash)
    assert_equal 86400, result[:m]
  end

  test "should return timestamp for correct timezone" do
    result = Celestial::EphemerisService.generate(:sun, year: 2024, month: 2, day: 4)

    timestamp = result[:t]
    time = Time.at(timestamp).in_time_zone("America/Los_Angeles")

    assert_equal 2024, time.year
    assert_equal 2, time.month
    assert_equal 4, time.day
    assert_equal 0, time.hour
    assert_equal 0, time.min
  end

  test "instance methods should validate and generate" do
    service = Celestial::EphemerisService.new(:sun, year: 2024, month: 2, day: 4)
    result = service.generate

    assert result.is_a?(Hash)
    assert_equal 86400, result[:m]
  end

  test "instance should handle invalid date in generate" do
    service = Celestial::EphemerisService.new(:sun, year: 2024, month: 13, day: 1)
    result = service.generate

    assert result.key?(:error)
    assert_match(/Invalid date/, result[:error])
  end
end
