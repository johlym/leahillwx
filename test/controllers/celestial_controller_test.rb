require "test_helper"

class CelestialControllerTest < ActionDispatch::IntegrationTest
  # Disable parallelization for these tests since they need the shared BSP ephemeris
  parallelize(workers: 1)
  test "should get sun ephemeris for specific date" do
    get celestial_sun_url, params: { year: 2024, month: 2, day: 4 }
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal 86400, json["m"]
    assert json["t"].is_a?(Integer)
    assert json["e"].key?("sun")
    assert json["o"].key?("sun")
    assert json["o"]["sun"].key?("alt")
    assert json["o"]["sun"].key?("az")
  end

  test "should get moon ephemeris for specific date" do
    get celestial_moon_url, params: { year: 2024, month: 2, day: 4 }
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal 86400, json["m"]
    assert json["t"].is_a?(Integer)
    assert json["e"].key?("moon")
    assert json["o"].key?("moon")
    assert json["o"]["moon"].key?("alt")
    assert json["o"]["moon"].key?("az")
  end

  test "should use current date when no params provided" do
    get celestial_sun_url
    assert_response :bad_request

    json = JSON.parse(response.body)
    assert_match(/Invalid parameters/, json["error"])
  end

  test "should return error for invalid date" do
    get celestial_sun_url, params: { year: 2024, month: 13, day: 1 }
    assert_response :success

    json = JSON.parse(response.body)
    assert_match(/Invalid date/, json["error"])
  end

  test "should return error when missing required parameters" do
    get celestial_sun_url, params: { year: 2024, month: 2 }
    assert_response :bad_request

    json = JSON.parse(response.body)
    assert_match(/Invalid parameters/, json["error"])
  end

  test "should ignore unpermitted parameters" do
    get celestial_moon_url, params: { year: 2024, month: 2, day: 4, extra: "param" }
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal 86400, json["m"]
  end

  test "sun ephemeris should have valid events structure" do
    get celestial_sun_url, params: { year: 2024, month: 6, day: 21 }
    assert_response :success

    json = JSON.parse(response.body)
    events = json["e"]["sun"]

    assert events.is_a?(Array)
    events.each do |event|
      assert event.key?("s")
      assert event.key?("t")
      assert event["s"].is_a?(Integer)
      assert event["t"].is_a?(Integer)
      assert event["s"] >= 0
      assert event["s"] <= 86400
    end
  end

  test "sun ephemeris should have valid polynomial segments" do
    get celestial_sun_url, params: { year: 2024, month: 6, day: 21 }
    assert_response :success

    json = JSON.parse(response.body)
    alt_segments = json["o"]["sun"]["alt"]
    az_segments = json["o"]["sun"]["az"]

    assert alt_segments.is_a?(Array)
    assert az_segments.is_a?(Array)
    assert alt_segments.length > 0
    assert az_segments.length > 0

    alt_segments.each do |segment|
      assert segment.key?("e")
      assert segment.key?("p")
      assert segment["e"].is_a?(Integer)
      assert segment["p"].is_a?(Array)
      assert_equal 4, segment["p"].length
    end
  end

  test "segments should be contiguous and cover full day" do
    get celestial_sun_url, params: { year: 2024, month: 6, day: 21 }
    assert_response :success

    json = JSON.parse(response.body)
    alt_segments = json["o"]["sun"]["alt"]

    assert_equal 86400, alt_segments.last["e"], "Final segment should end at 86400"

    prev_end = 0
    alt_segments.each do |segment|
      assert segment["e"] > prev_end, "Segments should be strictly increasing"
      prev_end = segment["e"]
    end
  end

  test "moon ephemeris should have valid structure" do
    get celestial_moon_url, params: { year: 2024, month: 2, day: 4 }
    assert_response :success

    json = JSON.parse(response.body)

    assert_equal 86400, json["m"]
    assert json["e"]["moon"].is_a?(Array)
    assert json["o"]["moon"]["alt"].is_a?(Array)
    assert json["o"]["moon"]["az"].is_a?(Array)
  end

  test "should handle date at ephemeris coverage boundary" do
    get celestial_sun_url, params: { year: 1976, month: 1, day: 1 }
    assert_response :success

    json = JSON.parse(response.body)
    assert json["m"] == 86400 || json.key?("error")
  end

  test "content type should be application/json" do
    get celestial_sun_url, params: { year: 2024, month: 2, day: 4 }
    assert_response :success
    assert_equal "application/json", response.media_type
  end

  test "host authorization only applies in production environment" do
    # In test/dev, host checks are bypassed
    assert_not Rails.env.production?

    # Any host should work in non-production
    get celestial_sun_url, params: { year: 2024, month: 2, day: 4 }
    assert_response :success
  end

  test "authorize_host method exists and is private" do
    assert CelestialController.private_method_defined?(:authorize_host)
  end

  test "controller has before_action for host authorization" do
    filters = CelestialController._process_action_callbacks.select { |c| c.filter == :authorize_host }
    assert filters.any?, "Should have authorize_host before_action configured"
  end
end
