# frozen_string_literal: true

require "test_helper"

class Elements::SkyArcComponentTest < ViewComponent::TestCase
  test "renders multi-body semicircle arcs" do
    rise = Time.zone.parse("2026-07-18 04:00:00")
    set = Time.zone.parse("2026-07-18 16:00:00")
    bodies = [
      {
        key: "venus",
        label: "Venus",
        rise_at: rise,
        set_at: set
      }
    ]

    render_inline(Elements::SkyArcComponent.new(bodies: bodies, now: rise + 3.hours))
    assert_text "Venus"
    assert_selector "svg path"
    assert_selector ".sky-arc-legend-row", text: "Venus"
  end

  test "glyph parks at rise before dawn and at set after dusk" do
    rise = Time.zone.parse("2026-07-18 06:00:00")
    set = Time.zone.parse("2026-07-18 18:00:00")
    body_attrs = { key: "sun", label: "Sun", rise_at: rise, set_at: set }

    before = Elements::SkyArcComponent.new(bodies: [ body_attrs ], now: rise - 1.hour)
    assert_in_delta 0.0, before.progress_for(before.bodies.first), 0.001
    assert_in_delta 10.0, before.current_point(before.bodies.first)[:x], 0.1
    assert_in_delta 100.0, before.current_point(before.bodies.first)[:y], 0.1

    after = Elements::SkyArcComponent.new(bodies: [ body_attrs ], now: set + 1.hour)
    assert_in_delta 1.0, after.progress_for(after.bodies.first), 0.001
    assert_in_delta 190.0, after.current_point(after.bodies.first)[:x], 0.1
    assert_in_delta 100.0, after.current_point(after.bodies.first)[:y], 0.1

    mid = Elements::SkyArcComponent.new(bodies: [ body_attrs ], now: rise + 6.hours)
    assert_in_delta 0.5, mid.progress_for(mid.bodies.first), 0.001
    point = mid.current_point(mid.bodies.first)
    assert_in_delta 100.0, point[:x], 0.1
    assert_operator point[:y], :<, 20
  end

  test "arc path is a single semicircle not a closed polyline" do
    component = Elements::SkyArcComponent.new(
      bodies: [ {
        key: "venus",
        label: "Venus",
        rise_at: Time.zone.parse("2026-07-18 09:00"),
        set_at: Time.zone.parse("2026-07-18 22:00")
      } ]
    )
    d = component.arc_d(component.bodies.first)
    assert_match(/\AM [\d.]+ 100 A /, d)
    assert_no_match(/ L /, d)
    assert_no_match(/Z\z/i, d)
  end

  test "does not render without rise/set" do
    component = Elements::SkyArcComponent.new(bodies: [ { key: "mars", label: "Mars" } ])
    assert_not component.render?
  end
end
