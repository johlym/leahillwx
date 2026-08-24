# frozen_string_literal: true

require "test_helper"

class PlanetNightTest < ActiveSupport::TestCase
  test "visible_planets hides a planet that rises after the card date" do
    night = PlanetNight.create!(
      date: Date.new(2026, 9, 8),
      timezone: "America/Los_Angeles",
      planets: [
        {
          "key" => "venus",
          "label" => "Venus",
          "rise_at" => "2026-09-08T10:33:25-07:00",
          "set_at" => "2026-09-08T21:14:21-07:00",
          "visible_tonight" => true
        },
        {
          "key" => "mars",
          "label" => "Mars",
          "rise_at" => "2026-09-09T01:39:48-07:00",
          "set_at" => "2026-09-09T17:24:50-07:00",
          "visible_tonight" => true
        }
      ]
    )

    assert_equal %w[venus], night.visible_planets.map { |planet| planet["key"] }
  end
end
