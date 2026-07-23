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
    assert_selector "[data-radar-target='loadProgress'][role='progressbar']", visible: :all
    # CSS uppercases chip labels; match case-insensitively on visible text.
    assert_selector "button.radar-site-chip", text: /composite/i
    assert_selector "button.radar-site-chip", text: "ATX"
    assert_no_selector "button[data-layer='cloud']"
    assert_no_selector "button[data-option='snow']"
    assert_no_selector "button[data-option='arrows']"
    assert_no_selector "button[data-option='alerts']"
    assert_text "lhwx.org"
    assert_text "LibreWXR"
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

  test "tilt selector appears only when a radar site is selected" do
    visit radar_url

    # Capybara ignores hidden nodes by default; assert the controls exist but are not shown.
    assert_selector "[data-radar-target='tiltControls'].hidden", visible: :hidden
    find("button.radar-site-chip", text: "ATX").click
    assert_selector "[data-radar-target='tiltControls']:not(.hidden)"
    assert_selector "button[data-radar-target='tiltChip'].is-active[data-tilt='0.5']"

    find("button[data-radar-target='tiltChip'][data-tilt='1.5']").click
    assert_selector "button[data-radar-target='tiltChip'].is-active[data-tilt='1.5']"

    find("button.radar-site-chip", text: /composite/i).click
    assert_selector "[data-radar-target='tiltControls'].hidden", visible: :hidden
  end
end
