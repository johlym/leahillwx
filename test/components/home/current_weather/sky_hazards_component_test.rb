# frozen_string_literal: true

require "test_helper"

class Home::CurrentWeather::SkyHazardsComponentTest < ViewComponent::TestCase
  test "appends +1 day when a planet sets on the next local date" do
    night = PlanetNight.create!(
      date: Date.new(2026, 8, 24),
      timezone: "America/Los_Angeles",
      planets: [
        {
          "key" => "venus",
          "label" => "Venus",
          "rise_at" => "2026-08-24T10:33:25-07:00",
          "set_at" => "2026-08-24T21:14:21-07:00",
          "visible_tonight" => true
        },
        {
          "key" => "saturn",
          "label" => "Saturn",
          "rise_at" => "2026-08-24T21:36:32-07:00",
          "set_at" => "2026-08-25T10:00:07-07:00",
          "visible_tonight" => true
        }
      ]
    )

    render_inline(Home::CurrentWeather::SkyHazardsComponent.new(
      wildfire: nil,
      aurora: nil,
      planet_night: night,
      iss_pass: nil
    ))

    assert_text "Venus"
    assert_text "10:33 AM - 9:14 PM"
    assert_no_text "9:14 PM +1 day"
    assert_text "Saturn"
    assert_text "9:36 PM - 10:00 AM +1 day"
  end

  test "shows every visible planet, not a three-item cap" do
    planets = %w[Venus Mars Jupiter Saturn].map.with_index do |label, index|
      {
        "key" => label.downcase,
        "label" => label,
        "rise_at" => "2026-08-24T20:00:00-07:00",
        "set_at" => "2026-08-25T06:0#{index}:00-07:00",
        "visible_tonight" => true
      }
    end
    night = PlanetNight.create!(
      date: Date.new(2026, 8, 24),
      timezone: "America/Los_Angeles",
      planets: planets
    )

    render_inline(Home::CurrentWeather::SkyHazardsComponent.new(
      wildfire: nil,
      aurora: nil,
      planet_night: night,
      iss_pass: nil
    ))

    planets.each { |planet| assert_text planet["label"] }
  end
end
