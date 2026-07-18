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

  test "does not render without rise/set" do
    component = Elements::SkyArcComponent.new(bodies: [ { key: "mars", label: "Mars" } ])
    assert_not component.render?
  end
end
