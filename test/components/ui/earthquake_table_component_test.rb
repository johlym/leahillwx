# frozen_string_literal: true

require "test_helper"

class Home::EarthquakeTableComponentTest < ViewComponent::TestCase
  test "renders table with correct structure" do
    earthquakes = [ earthquakes(:one) ]
    render_inline(Home::EarthquakeTableComponent.new(earthquakes: earthquakes))

    assert_selector "div.earthquake-table"
    assert_selector "div.eq-header"
    assert_selector "div.eq-body"
  end

  test "renders table headers" do
    render_inline(Home::EarthquakeTableComponent.new(earthquakes: []))

    assert_selector "div.eq-header-cell", text: "Mag"
    assert_selector "div.eq-header-cell", text: "Timestamp"
    assert_selector "div.eq-header-cell", text: "Location"
    assert_selector "div.eq-header-cell", text: "Distance"
    assert_selector "div.eq-header-cell", text: "Depth"
  end

  test "renders earthquake data" do
    earthquake = earthquakes(:one)
    render_inline(Home::EarthquakeTableComponent.new(earthquakes: [ earthquake ]))

    assert_selector "div.eq-mag-cell", text: earthquake.magnitude.to_s
    assert_selector "div.eq-cell", text: earthquake.place
  end

  test "renders formatted time" do
    earthquake = earthquakes(:one)
    render_inline(Home::EarthquakeTableComponent.new(earthquakes: [ earthquake ]))

    expected_date = earthquake.eventtime.in_time_zone("America/Los_Angeles").strftime("%B %d, %Y")
    expected_time = earthquake.eventtime.in_time_zone("America/Los_Angeles").strftime("%I:%M %p")

    assert_selector "div.eq-cell", text: /#{Regexp.escape(expected_date)}/
    assert_selector "div.eq-cell", text: /#{Regexp.escape(expected_time)}/
  end

  test "renders distance with precision" do
    earthquake = earthquakes(:one)
    render_inline(Home::EarthquakeTableComponent.new(earthquakes: [ earthquake ]))

    assert_selector "div.eq-cell", text: /999\.99 mi/
  end

  test "renders depth with precision" do
    earthquake = earthquakes(:one)
    render_inline(Home::EarthquakeTableComponent.new(earthquakes: [ earthquake ]))

    assert_selector "div.eq-cell", text: /100\.00 mi/
  end

  test "renders USGS link" do
    earthquake = earthquakes(:one)
    render_inline(Home::EarthquakeTableComponent.new(earthquakes: [ earthquake ]))

    assert_selector "a[href='#{earthquake.url}'][target='blank']", text: earthquake.place
  end

  test "renders multiple earthquakes" do
    earthquake1 = earthquakes(:one)
    earthquake2 = Earthquake.create!(
      magnitude: 2.5,
      place: "Another Place",
      eventtime: Time.current,
      distance: 50.0,
      depth: 10.0,
      lat: 35.0,
      lon: -119.0,
      url: "https://example.com/2",
      last_updated: Time.current,
      usgs_id: "test123"
    )

    render_inline(Home::EarthquakeTableComponent.new(earthquakes: [ earthquake1, earthquake2 ]))

    assert_selector "div.eq-row", count: 2
  end

  test "renders empty table when no earthquakes" do
    render_inline(Home::EarthquakeTableComponent.new(earthquakes: []))

    assert_selector "div.earthquake-table"
    assert_selector "div.eq-row", count: 0
  end
end
