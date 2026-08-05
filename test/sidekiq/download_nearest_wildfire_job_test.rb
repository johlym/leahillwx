# frozen_string_literal: true

require "test_helper"

class DownloadNearestWildfireJobTest < ActiveSupport::TestCase
  test "persists nearest wildfire snapshot" do
    fire = {
      name: "Test Fire",
      lat: 47.0,
      lon: -121.0,
      distance_mi: 42.0,
      acres: 10.0,
      percent_contained: 25.0,
      url: "https://example.com",
      source: "wadnr+nifc",
      external_id: "abc"
    }

    stub_resolver(fire) do
      assert_difference "WildfireSnapshot.count", 1 do
        DownloadNearestWildfireJob.new.perform
      end
    end

    snapshot = WildfireSnapshot.latest_active
    assert_equal "Test Fire", snapshot.name
    assert_equal 25.0, snapshot.percent_contained
    assert snapshot.active?
  end

  test "persists inactive marker when no live fires remain" do
    WildfireSnapshot.create!(
      name: "Stale Fire",
      lat: 47.0,
      lon: -121.0,
      distance_mi: 5,
      source: "wadnr",
      active: true,
      fetched_at: 1.hour.ago
    )

    stub_resolver(nil) do
      with_env("LOCATION_LAT" => "47.3", "LOCATION_LON" => "-122.2") do
        assert_difference "WildfireSnapshot.count", 1 do
          DownloadNearestWildfireJob.new.perform
        end
      end
    end

    assert_nil WildfireSnapshot.latest_active
    marker = WildfireSnapshot.latest
    assert_not marker.active?
    assert_equal "none", marker.source
  end

  private

  def stub_resolver(result)
    fake = Object.new
    fake.define_singleton_method(:call) { result }
    NearestWildfireResolver.singleton_class.alias_method(:__orig_new, :new)
    NearestWildfireResolver.define_singleton_method(:new) { |*_args| fake }
    yield
  ensure
    NearestWildfireResolver.singleton_class.remove_method(:new)
    NearestWildfireResolver.singleton_class.alias_method(:new, :__orig_new)
    NearestWildfireResolver.singleton_class.remove_method(:__orig_new)
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
