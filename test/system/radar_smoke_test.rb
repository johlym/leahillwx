# frozen_string_literal: true

require "application_system_test_case"

class RadarSmokeTest < ApplicationSystemTestCase
  setup do
    @original_lat = ENV["LOCATION_LAT"]
    @original_lon = ENV["LOCATION_LON"]
    ENV["LOCATION_LAT"] = "47.3073"
    ENV["LOCATION_LON"] = "-122.2285"
  end

  teardown do
    ENV["LOCATION_LAT"] = @original_lat
    ENV["LOCATION_LON"] = @original_lon
  end

  test "radar page loads with map shell and controls" do
    visit radar_url

    assert_selector "body.radar-page"
    assert_selector "[data-controller='radar']"
    assert_selector "[data-radar-target='map']"
    # CSS uppercases chip labels; match case-insensitively on visible text.
    assert_selector "button.radar-site-chip", text: /composite/i
    assert_selector "button.radar-site-chip", text: "ATX"
    assert_text "lhwx.org"
  end

  test "radar page is usable at a phone-sized viewport" do
    page.current_window.resize_to(390, 844)
    visit radar_url

    assert_selector "body.radar-page"
    assert_selector ".radar-controls"
    assert_selector ".radar-controls-sites"
    assert_selector "[data-radar-target='playPause']"
    assert_selector "footer.site-footer-radar"
    assert_no_selector ".site-footer p", text: /Data is not guaranteed/
  end

  test "site chip selection updates pressed state" do
    visit radar_url

    find("button.radar-site-chip", text: "ATX").click
    assert_selector "button.radar-site-chip.is-active[data-site-id='KATX'][aria-pressed='true']"

    find("button.radar-site-chip", text: /composite/i).click
    assert_selector "button.radar-site-chip.is-active[data-site-id=''][aria-pressed='true']"
  end
end
