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

  private

  def stubbed_generator
    payload = @payload
    Class.new(Almanac::PlanetNightGenerator) do
      define_method(:initialize) { |_args = nil| }
      define_method(:generate) { |_date = nil| payload }
    end.new
  end
end
