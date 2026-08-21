# frozen_string_literal: true

require "test_helper"

class Home::CurrentWeather::SkyHazardsComponentTest < ViewComponent::TestCase
  test "labels an uncontrolled fire as uncontained with a danger badge" do
    fire = wildfire_snapshot(percent_contained: 0, acres: 1_500)

    render_inline(component(wildfire: fire))

    assert_text "Creek Fire"
    assert_text "Uncontained"
    assert_text "1500 acres"
    assert_no_text "Contained"
    assert_selector ".status-badge-danger"
    assert_no_selector ".status-badge-success"
  end

  test "does not treat missing containment as contained" do
    fire = wildfire_snapshot(percent_contained: nil)

    render_inline(component(wildfire: fire))

    assert_text "Uncontained"
    assert_no_text "Contained"
    assert_selector ".status-badge-danger"
  end

  test "shows partial containment with a warning badge" do
    fire = wildfire_snapshot(percent_contained: 40)

    render_inline(component(wildfire: fire))

    assert_text "40% contained"
    assert_no_text "Uncontained"
    assert_selector ".status-badge-warning"
    assert_no_selector ".status-badge-success"
  end

  test "uses a success badge only when the fire is fully contained" do
    fire = wildfire_snapshot(percent_contained: 100)

    render_inline(component(wildfire: fire))

    assert_text "Contained"
    assert_no_text "Uncontained"
    assert_selector ".status-badge-success"
  end

  test "renders the empty state when no live fire is present" do
    render_inline(component(wildfire: nil))

    assert_text "No active fires reported nearby."
    assert_no_selector ".status-badge"
  end

  private

  def component(wildfire:)
    Home::CurrentWeather::SkyHazardsComponent.new(
      wildfire: wildfire,
      aurora: nil,
      planet_night: nil,
      iss_pass: nil
    )
  end

  def wildfire_snapshot(percent_contained:, acres: nil)
    WildfireSnapshot.new(
      name: "Creek Fire",
      lat: 47.0,
      lon: -122.0,
      distance_mi: 12,
      source: "wadnr",
      active: true,
      percent_contained: percent_contained,
      acres: acres,
      fetched_at: Time.current
    )
  end
end
