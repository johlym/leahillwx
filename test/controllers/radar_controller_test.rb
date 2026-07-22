# frozen_string_literal: true

require "test_helper"

class RadarControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_lat = ENV["LOCATION_LAT"]
    @original_lon = ENV["LOCATION_LON"]
    @original_librewxr = ENV["LIBREWXR_API_BASE"]
    ENV["LOCATION_LAT"] = "47.3073"
    ENV["LOCATION_LON"] = "-122.2285"
    ENV.delete("LIBREWXR_API_BASE")
  end

  teardown do
    ENV["LOCATION_LAT"] = @original_lat
    ENV["LOCATION_LON"] = @original_lon
    if @original_librewxr
      ENV["LIBREWXR_API_BASE"] = @original_librewxr
    else
      ENV.delete("LIBREWXR_API_BASE")
    end
  end

  test "index renders successfully" do
    get radar_url
    assert_response :success
  end

  test "index uses radar-page body class for full-viewport layout" do
    get radar_url
    assert_select "body.radar-page"
    assert_select "body.radar-page main.site-main"
  end

  test "index mounts Stimulus radar controller with station coordinates" do
    get radar_url
    assert_select "[data-controller='radar'][data-radar-lat-value='47.3073'][data-radar-lon-value='-122.2285']"
    assert_select "[data-radar-target='map'][role='application']"
    assert_select "[data-radar-librewxr-host-value='https://api.librewxr.net']"
  end

  test "index uses LIBREWXR_API_BASE when configured" do
    ENV["LIBREWXR_API_BASE"] = "https://radar.example.com"
    get radar_url
    assert_select "[data-radar-librewxr-host-value='https://radar.example.com']"
  ensure
    ENV.delete("LIBREWXR_API_BASE")
  end

  test "index embeds the three local radar sites as JSON" do
    get radar_url
    body = response.body
    assert_includes body, "KATX"
    assert_includes body, "KRTX"
    assert_includes body, "KLGX"
    assert_includes body, "Camano Island"
    assert_includes body, "Portland"
    assert_includes body, "Langley Hill"
  end

  test "index renders playback and site selection controls" do
    get radar_url
    assert_select "[data-radar-target='playPause']"
    assert_select "[data-radar-target='timestamp']"
    assert_select "button.radar-site-chip[data-site-id='']", text: "Composite"
    assert_select "button.radar-site-chip[data-site-id='KATX']", text: "ATX"
    assert_select "button.radar-site-chip[data-site-id='KRTX']", text: "RTX"
    assert_select "button.radar-site-chip[data-site-id='KLGX']", text: "LGX"
  end

  test "index renders layer and option chips for LibreWXR composite" do
    get radar_url
    assert_select "[data-radar-target='layerControls']"
    assert_select "button[data-radar-target='layerChip'][data-layer='precip']", text: "Precip"
    assert_select "button[data-radar-target='layerChip'][data-layer='cloud']", text: "Cloud"
    assert_select "button[data-radar-target='optionChip'][data-option='arrows']", text: "Arrows"
    assert_select "button[data-radar-target='optionChip'][data-option='snow']", text: "Snow"
    assert_select "button[data-radar-target='optionChip'][data-option='alerts']", text: "Alerts"
    assert_select "[data-radar-target='alertBanner'].hidden"
  end

  test "index renders hidden tilt controls for single-site reflectivity" do
    get radar_url
    assert_select "[data-radar-target='tiltControls'].hidden"
    assert_select "#radar-tilt-label", text: "Tilt"
    assert_select "button[data-radar-target='tiltChip'][data-tilt='0.5']", text: "0.5°"
    assert_select "button[data-radar-target='tiltChip'][data-tilt='1.0']", text: "1.0°"
    assert_select "button[data-radar-target='tiltChip'][data-tilt='1.5']", text: "1.5°"
  end

  test "index uses the slim radar footer instead of the full site footer" do
    get radar_url
    assert_select "footer.site-footer.site-footer-radar"
    assert_select "footer.site-footer-radar a[href='https://librewxr.net/']"
    assert_select "footer.site-footer-radar a[href='https://carto.com/attributions']"
    assert_no_match(/RainViewer/, response.body)
    assert_no_match(/Data is not guaranteed to be accurate/, response.body)
    assert_no_match(/Measurement no\./, response.body)
  end

  test "header includes Radar nav link on desktop and mobile menus" do
    get radar_url
    assert_select ".site-header-links a[href=?]", radar_path, text: "Radar"
    assert_select ".site-header-mobile-links a[href=?]", radar_path, text: "Radar"
  end

  test "Radar nav link is marked active on the radar page" do
    get radar_url
    assert_select ".site-header-links a.nav-link-active[href=?]", radar_path, text: "Radar"
  end

  test "index requires LOCATION_LAT and LOCATION_LON" do
    ENV.delete("LOCATION_LAT")
    ENV.delete("LOCATION_LON")

    assert_raises(KeyError) { get radar_url }
  end

  test "other pages still render the full footer" do
    get about_url
    assert_response :success
    assert_select ".site-footer"
    assert_select "footer.site-footer-radar", count: 0
  end
end
