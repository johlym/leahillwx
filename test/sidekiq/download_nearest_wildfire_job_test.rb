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

    fake = Object.new
    fake.define_singleton_method(:call) { fire }
    NearestWildfireResolver.singleton_class.alias_method(:__orig_new, :new)
    NearestWildfireResolver.define_singleton_method(:new) { |*_args| fake }

    assert_difference "WildfireSnapshot.count", 1 do
      DownloadNearestWildfireJob.new.perform
    end

    snapshot = WildfireSnapshot.latest
    assert_equal "Test Fire", snapshot.name
    assert_equal 25.0, snapshot.percent_contained
  ensure
    NearestWildfireResolver.singleton_class.remove_method(:new)
    NearestWildfireResolver.singleton_class.alias_method(:new, :__orig_new)
    NearestWildfireResolver.singleton_class.remove_method(:__orig_new)
  end
end
