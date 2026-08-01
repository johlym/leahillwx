# frozen_string_literal: true

require "test_helper"

class DownloadLatestEarthquakeJobTest < ActiveSupport::TestCase
  def sample_api_response(usgs_id: "us7000abcd", magnitude: 4.2)
    {
      magnitude: magnitude,
      place: "10km NW of Somewhere, CA",
      eventtime: Time.utc(2024, 3, 14, 15, 9, 26),
      last_updated: Time.utc(2024, 3, 14, 15, 30, 0),
      url: "https://earthquake.usgs.gov/earthquakes/eventpage/#{usgs_id}",
      lat: 35.0,
      lon: -119.0,
      depth: 12.5,
      usgs_id: usgs_id
    }
  end

  def stub_api(response)
    fake = Struct.new(:response) do
      def get_latest_earthquake = response
    end.new(response)

    UsgsEarthquakeClient.singleton_class.alias_method(:__orig_new, :new)
    UsgsEarthquakeClient.define_singleton_method(:new) { |*_args| fake }
    begin
      yield
    ensure
      UsgsEarthquakeClient.singleton_class.remove_method(:new)
      UsgsEarthquakeClient.singleton_class.alias_method(:new, :__orig_new)
      UsgsEarthquakeClient.singleton_class.remove_method(:__orig_new)
    end
  end

  test "creates a new earthquake when the USGS id is unseen" do
    response = sample_api_response(usgs_id: "us7000newone")

    assert_difference "Earthquake.count", 1 do
      stub_api(response) { DownloadLatestEarthquakeJob.new.perform }
    end

    earthquake = Earthquake.find_by!(usgs_id: "us7000newone")
    assert_equal 4.2, earthquake.magnitude
    assert_equal "10km NW of Somewhere, CA", earthquake.place
    assert_equal 35.0, earthquake.lat
    assert_equal(-119.0, earthquake.lon)
    assert_equal 12.5, earthquake.depth
    assert_not earthquake.revised, "new earthquakes should not be marked revised"
  end

  test "no-ops when USGS returns no earthquake" do
    assert_no_difference "Earthquake.count" do
      stub_api(nil) { DownloadLatestEarthquakeJob.new.perform }
    end
  end

  test "assigns distance computed from ENV location and event coordinates" do
    response = sample_api_response(usgs_id: "us7000dist")
    with_env("LOCATION_LAT" => "36", "LOCATION_LON" => "-120") do
      stub_api(response) { DownloadLatestEarthquakeJob.new.perform }
    end

    earthquake = Earthquake.find_by!(usgs_id: "us7000dist")
    expected = GeoDistance.distance(35.0, -119.0, 36, -120, unit: :mi)
    assert_in_delta expected, earthquake.distance, 0.0001
  end

  test "marks an existing earthquake as revised and updates attributes" do
    existing = Earthquake.create!(
      usgs_id: "us7000existing",
      magnitude: 3.0,
      place: "Old place",
      eventtime: Time.utc(2024, 1, 1, 0, 0, 0),
      last_updated: Time.utc(2024, 1, 1, 0, 0, 0),
      url: "https://example.com/old",
      lat: 34.0,
      lon: -118.0,
      depth: 5.0,
      distance: 100.0,
      revised: false
    )

    response = sample_api_response(usgs_id: "us7000existing", magnitude: 4.8)

    assert_no_difference "Earthquake.count" do
      stub_api(response) { DownloadLatestEarthquakeJob.new.perform }
    end

    existing.reload
    assert existing.revised, "existing earthquakes should be flagged as revised on re-download"
    assert_equal 4.8, existing.magnitude
    assert_equal "10km NW of Somewhere, CA", existing.place
    assert_equal 35.0, existing.lat
    assert_equal(-119.0, existing.lon)
  end

  test "leaves the usgs_id untouched when updating an existing record" do
    existing = Earthquake.create!(
      usgs_id: "us7000stable",
      magnitude: 2.0,
      place: "Somewhere",
      eventtime: Time.utc(2024, 1, 1, 0, 0, 0),
      last_updated: Time.utc(2024, 1, 1, 0, 0, 0),
      url: "https://example.com/x",
      lat: 0,
      lon: 0,
      depth: 0,
      distance: 25.0
    )
    response = sample_api_response(usgs_id: "us7000stable")

    stub_api(response) { DownloadLatestEarthquakeJob.new.perform }

    assert_equal "us7000stable", existing.reload.usgs_id
  end

  test "logs and continues when the USGS client raises RequestError" do
    assert_no_difference "Earthquake.count" do
      stub_api_error(HttpClient::RequestError.new("HTTP GET failed: Net::ReadTimeout")) do
        DownloadLatestEarthquakeJob.new.perform
      end
    end
  end

  private

  def stub_api_error(error)
    UsgsEarthquakeClient.singleton_class.alias_method(:__orig_new, :new)
    UsgsEarthquakeClient.define_singleton_method(:new) do |*_args|
      Object.new.tap do |fake|
        fake.define_singleton_method(:get_latest_earthquake) { raise error }
      end
    end
    begin
      yield
    ensure
      UsgsEarthquakeClient.singleton_class.remove_method(:new)
      UsgsEarthquakeClient.singleton_class.alias_method(:new, :__orig_new)
      UsgsEarthquakeClient.singleton_class.remove_method(:__orig_new)
    end
  end


  def with_env(vars)
    originals = vars.transform_values { |_| :__unset__ }
    vars.each_key { |k| originals[k] = ENV[k] }
    vars.each { |k, v| ENV[k] = v }
    yield
  ensure
    originals.each do |k, original|
      original == :__unset__ ? ENV.delete(k) : ENV[k] = original
    end
  end
end
