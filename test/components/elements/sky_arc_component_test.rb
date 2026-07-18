# frozen_string_literal: true

require "test_helper"

class Elements::SkyArcComponentTest < ViewComponent::TestCase
  test "renders multi-body alt/az paths" do
    rise = Time.zone.parse("2026-07-18 04:00:00")
    set = Time.zone.parse("2026-07-18 16:00:00")
    bodies = [
      {
        key: "venus",
        label: "Venus",
        rise_at: rise,
        set_at: set,
        samples: [
          { "at" => rise.iso8601, "az_deg" => 90, "alt_deg" => 5 },
          { "at" => (rise + 6.hours).iso8601, "az_deg" => 180, "alt_deg" => 40 },
          { "at" => set.iso8601, "az_deg" => 270, "alt_deg" => 5 }
        ]
      }
    ]

    render_inline(Elements::SkyArcComponent.new(bodies: bodies, now: rise + 3.hours))
    assert_text "Venus"
    assert_selector "svg path"
    assert_selector ".sky-arc-legend-row", text: "Venus"
  end

  test "alt/az projection keeps southern sky points above the horizon" do
    component = Elements::SkyArcComponent.new(
      bodies: [ {
        key: "sun",
        label: "Sun",
        rise_at: Time.zone.parse("2026-07-18 05:00"),
        set_at: Time.zone.parse("2026-07-18 21:00"),
        samples: [
          { "at" => "2026-07-18T05:00:00Z", "az_deg" => 90, "alt_deg" => 0 },
          { "at" => "2026-07-18T13:00:00Z", "az_deg" => 180, "alt_deg" => 60 },
          { "at" => "2026-07-18T21:00:00Z", "az_deg" => 270, "alt_deg" => 0 }
        ]
      } ]
    )

    points = component.path_points(component.bodies.first)
    assert points.any?
    # Horizon is y=100; sky is y < 100. Allow a tiny float epsilon on the rim.
    points.each do |pt|
      assert_operator pt[:y], :<=, 100.01, "expected y=#{pt[:y]} at x=#{pt[:x]} to stay on/above horizon"
    end
    # Transit (south / high altitude) should sit clearly above the horizon.
    mid = points[1]
    assert_operator mid[:y], :<, 90
  end

  test "does not render without rise/set" do
    component = Elements::SkyArcComponent.new(bodies: [ { key: "mars", label: "Mars" } ])
    assert_not component.render?
  end
end
