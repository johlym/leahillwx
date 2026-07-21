# frozen_string_literal: true

require "test_helper"

class RadarControllerTest < ActionDispatch::IntegrationTest
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

  test "index uses the slim radar footer instead of the full site footer" do
    get radar_url
    assert_select "footer.site-footer.site-footer-radar"
    assert_select "footer.site-footer-radar a[href='https://mesonet.agron.iastate.edu/']"
    assert_select "footer.site-footer-radar a[href='https://www.rainviewer.com/']"
    assert_select "footer.site-footer-radar a[href='https://carto.com/attributions']"
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
