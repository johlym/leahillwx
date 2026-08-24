# frozen_string_literal: true

require "test_helper"

class Home::CurrentWeather::SkyHazardsComponentTest < ViewComponent::TestCase
  test "appends +1 day to rise or set when that clock is the next local date" do
    night = PlanetNight.create!(
      date: Date.new(2026, 9, 1),
      timezone: "America/Los_Angeles",
      planets: [
        {
          "key" => "venus",
          "label" => "Venus",
          "rise_at" => "2026-09-01T10:33:25-07:00",
          "set_at" => "2026-09-01T21:14:21-07:00",
          "visible_tonight" => true
        },
        {
          "key" => "mars",
          "label" => "Mars",
          "rise_at" => "2026-09-02T01:39:48-07:00",
          "set_at" => "2026-09-02T17:24:50-07:00",
          "visible_tonight" => true
        },
        {
          "key" => "saturn",
          "label" => "Saturn",
          "rise_at" => "2026-09-01T21:36:32-07:00",
          "set_at" => "2026-09-02T10:00:07-07:00",
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
    assert_no_text "Mars"
    assert_text "Saturn"
    assert_text "9:36 PM - 10:00 AM +1 day"
  end

  test "omits planets that rise after the card date" do
    night = PlanetNight.create!(
      date: Date.new(2026, 9, 6),
      timezone: "America/Los_Angeles",
      planets: [
        {
          "key" => "mars",
          "label" => "Mars",
          "rise_at" => "2026-09-07T01:39:48-07:00",
          "set_at" => "2026-09-07T17:24:50-07:00",
          "visible_tonight" => true
        },
        {
          "key" => "saturn",
          "label" => "Saturn",
          "rise_at" => "2026-09-06T21:36:32-07:00",
          "set_at" => "2026-09-07T10:00:07-07:00",
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

    assert_no_text "Mars"
    assert_text "Saturn"
  end

  test "shows every visible planet, not a three-item cap" do
    planets = %w[Venus Mars Jupiter Saturn].map.with_index do |label, index|
      {
        "key" => label.downcase,
        "label" => label,
        "rise_at" => "2026-09-01T20:00:00-07:00",
        "set_at" => "2026-09-02T06:0#{index}:00-07:00",
        "visible_tonight" => true
      }
    end
    night = PlanetNight.create!(
      date: Date.new(2026, 9, 1),
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

  test "planet meter is elapsed transit progress, not rise-to-set duration" do
    night = PlanetNight.create!(
      date: Date.new(2026, 9, 3),
      timezone: "America/Los_Angeles",
      planets: [
        {
          "key" => "venus",
          "label" => "Venus",
          "rise_at" => "2026-09-03T10:32:13-07:00",
          "set_at" => "2026-09-03T21:17:13-07:00",
          "visible_tonight" => true
        },
        {
          "key" => "mars",
          "label" => "Mars",
          "rise_at" => "2026-09-04T01:40:46-07:00",
          "set_at" => "2026-09-04T17:26:09-07:00",
          "visible_tonight" => true
        },
        {
          "key" => "saturn",
          "label" => "Saturn",
          "rise_at" => "2026-09-03T21:40:32-07:00",
          "set_at" => "2026-09-04T10:04:18-07:00",
          "visible_tonight" => true
        }
      ]
    )
    now = Time.zone.parse("2026-09-03T21:51:00-07:00")
    component = Home::CurrentWeather::SkyHazardsComponent.new(
      wildfire: nil,
      aurora: nil,
      planet_night: night,
      iss_pass: nil,
      now: now
    )
    planets = night.planets.index_by { |planet| planet["key"] }

    assert_equal 100, component.planet_visibility_pct(planets["venus"])
    assert_equal 0, component.planet_visibility_pct(planets["mars"])
    assert_operator component.planet_visibility_pct(planets["saturn"]), :<, 10
  end

  test "afternoon on the card date does not fill a morning planet that rises tomorrow" do
    night = PlanetNight.create!(
      date: Date.new(2026, 9, 4),
      timezone: "America/Los_Angeles",
      planets: [
        {
          "key" => "mars",
          "label" => "Mars",
          "rise_at" => "2026-09-05T01:39:48-07:00",
          "set_at" => "2026-09-05T17:24:50-07:00",
          "visible_tonight" => true
        }
      ]
    )
    afternoon = Time.zone.parse("2026-09-04T14:49:00-07:00")
    next_afternoon = Time.zone.parse("2026-09-05T14:49:00-07:00")
    planet = night.planets.first

    before_rise = Home::CurrentWeather::SkyHazardsComponent.new(
      wildfire: nil, aurora: nil, planet_night: night, iss_pass: nil, now: afternoon
    )
    after_rise = Home::CurrentWeather::SkyHazardsComponent.new(
      wildfire: nil, aurora: nil, planet_night: night, iss_pass: nil, now: next_afternoon
    )

    assert_equal 0, before_rise.planet_visibility_pct(planet)
    assert_operator after_rise.planet_visibility_pct(planet), :>, 50
  end
end
