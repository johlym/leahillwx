# frozen_string_literal: true

require "test_helper"

class Almanac::PlanetNightGeneratorTest < ActiveSupport::TestCase
  setup do
    @date = Date.new(2026, 8, 3)
    @planets = [
      {
        "key" => "venus",
        "label" => "Venus",
        "visible_tonight" => true
      }
    ]
    @payload = {
      date: @date,
      timezone: "America/Los_Angeles",
      planets: @planets
    }
  end

  test "generate_and_persist! creates a planet night for the date" do
    record = stubbed_generator.generate_and_persist!(@date)

    assert_equal @date, record.date
    assert_equal "America/Los_Angeles", record.timezone
    assert_equal @planets, record.planets
    assert_equal 1, PlanetNight.where(date: @date).count
  end

  test "generate_and_persist! updates an existing planet night for the date" do
    PlanetNight.create!(
      date: @date,
      timezone: "America/Los_Angeles",
      planets: [ { "key" => "mars", "visible_tonight" => false } ]
    )

    record = stubbed_generator.generate_and_persist!(@date)

    assert_equal @planets, record.planets
    assert_equal 1, PlanetNight.where(date: @date).count
  end

  test "generate_and_persist! is safe under concurrent writers for the same date" do
    errors = []
    threads = Array.new(2) do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          stubbed_generator.generate_and_persist!(@date)
        end
      rescue StandardError => e
        errors << e
      end
    end
    threads.each(&:join)

    assert_empty errors
    assert_equal 1, PlanetNight.where(date: @date).count
    assert_equal @planets, PlanetNight.find_by!(date: @date).planets
  end

  test "evening star is visible when it sets after civil dusk" do
    zone = ActiveSupport::TimeZone["America/Los_Angeles"]
    date = Date.new(2026, 8, 24)
    rise = zone.local(2026, 8, 24, 10, 33)
    set_at = zone.local(2026, 8, 24, 21, 14)

    planet = generate_planet(
      date: date,
      dusk: zone.local(2026, 8, 24, 20, 35),
      dawn: zone.local(2026, 8, 25, 5, 44),
      up_at_start: false,
      crossings: [
        { time: rise, direction: :rising },
        { time: set_at, direction: :setting }
      ]
    )

    assert planet["visible_tonight"]
    assert_equal rise.iso8601, planet["rise_at"]
    assert_equal set_at.iso8601, planet["set_at"]
  end

  test "morning planet is visible on the predawn rise, not the first daylight interval" do
    zone = ActiveSupport::TimeZone["America/Los_Angeles"]
    date = Date.new(2026, 8, 24)
    first_rise = zone.local(2026, 8, 24, 1, 40)
    first_set = zone.local(2026, 8, 24, 17, 26)
    night_rise = zone.local(2026, 8, 25, 1, 39)
    night_set = zone.local(2026, 8, 25, 17, 24)

    planet = generate_planet(
      date: date,
      dusk: zone.local(2026, 8, 24, 20, 35),
      dawn: zone.local(2026, 8, 25, 5, 44),
      up_at_start: false,
      crossings: [
        { time: first_rise, direction: :rising },
        { time: first_set, direction: :setting },
        { time: night_rise, direction: :rising },
        { time: night_set, direction: :setting }
      ]
    )

    assert planet["visible_tonight"]
    assert_equal night_rise.iso8601, planet["rise_at"]
    assert_equal night_set.iso8601, planet["set_at"]
  end

  test "already-up outer planet is visible on tonight's rise after the morning set" do
    zone = ActiveSupport::TimeZone["America/Los_Angeles"]
    date = Date.new(2026, 8, 24)
    morning_set = zone.local(2026, 8, 24, 10, 4)
    night_rise = zone.local(2026, 8, 24, 21, 36)
    next_set = zone.local(2026, 8, 25, 10, 0)

    planet = generate_planet(
      date: date,
      dusk: zone.local(2026, 8, 24, 20, 35),
      dawn: zone.local(2026, 8, 25, 5, 44),
      up_at_start: true,
      crossings: [
        { time: morning_set, direction: :setting },
        { time: night_rise, direction: :rising },
        { time: next_set, direction: :setting }
      ]
    )

    assert planet["visible_tonight"]
    assert_equal night_rise.iso8601, planet["rise_at"]
    assert_equal next_set.iso8601, planet["set_at"]
    assert Time.iso8601(planet["rise_at"]) < Time.iso8601(planet["set_at"])
  end

  test "planet that sets before dusk and rises after dawn is not visible tonight" do
    zone = ActiveSupport::TimeZone["America/Los_Angeles"]
    date = Date.new(2026, 8, 24)

    planet = generate_planet(
      date: date,
      dusk: zone.local(2026, 8, 24, 20, 35),
      dawn: zone.local(2026, 8, 25, 5, 44),
      up_at_start: false,
      crossings: [
        { time: zone.local(2026, 8, 24, 5, 57), direction: :rising },
        { time: zone.local(2026, 8, 24, 20, 2), direction: :setting },
        { time: zone.local(2026, 8, 25, 6, 4), direction: :rising },
        { time: zone.local(2026, 8, 25, 20, 2), direction: :setting }
      ]
    )

    assert_not planet["visible_tonight"]
    assert_nil planet["rise_at"]
    assert_nil planet["set_at"]
  end

  test "generate marks the August 2026 morning and already-up planets visible" do
    payload = Almanac::PlanetNightGenerator.new(
      lat: 47.3073,
      lon: -122.2285
    ).generate(Date.new(2026, 8, 24))

    visibility = payload[:planets].to_h { |planet| [ planet["key"], planet["visible_tonight"] ] }

    assert_equal false, visibility["mercury"]
    assert_equal true, visibility["venus"]
    assert_equal true, visibility["mars"]
    assert_equal true, visibility["jupiter"]
    assert_equal true, visibility["saturn"]

    saturn = payload[:planets].find { |planet| planet["key"] == "saturn" }
    assert Time.iso8601(saturn["rise_at"]) < Time.iso8601(saturn["set_at"]),
           "Saturn rise/set must be a paired apparition, not first-rise + first-set"
  end

  private

  def stubbed_generator
    payload = @payload
    Class.new(Almanac::PlanetNightGenerator) do
      define_method(:initialize) { |_args = nil| }
      define_method(:generate) { |_date = nil| payload }
    end.new
  end

  def generate_planet(date:, dusk:, dawn:, crossings:, up_at_start:)
    pairing_generator(
      dusk: dusk,
      dawn: dawn,
      crossings: crossings,
      up_at_start: up_at_start
    ).generate(date)[:planets].first
  end

  def pairing_generator(dusk:, dawn:, crossings:, up_at_start:)
    horizon = Object.new
    horizon.define_singleton_method(:civil_dusk) { |*| dusk }
    horizon.define_singleton_method(:civil_dawn) { |*| dawn }
    horizon.define_singleton_method(:horizon_crossings) { |*| crossings }
    horizon.define_singleton_method(:transit) { |*| nil }

    start_altitude = up_at_start ? 10.0 : -10.0
    bsp = Object.new
    bsp.define_singleton_method(:position_for) do |*|
      { altitude: start_altitude, azimuth: 180.0 }
    end

    Class.new(Almanac::PlanetNightGenerator) do
      define_method(:initialize) do
        @timezone = "America/Los_Angeles"
        @horizon = horizon
        @bsp = bsp
      end
    end.new
  end
end
