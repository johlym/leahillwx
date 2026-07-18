# frozen_string_literal: true

require "test_helper"

class NearestWildfireResolverTest < ActiveSupport::TestCase
  def stub_clients(dnr:, nifc:)
    dnr_fake = Object.new
    dnr_fake.define_singleton_method(:active_fires) { dnr }
    nifc_fake = Object.new
    nifc_fake.define_singleton_method(:active_fires) { nifc }

    WaDnrWildfireClient.singleton_class.alias_method(:__orig_new, :new)
    NifcWildfireClient.singleton_class.alias_method(:__orig_new, :new)
    WaDnrWildfireClient.define_singleton_method(:new) { |*_args| dnr_fake }
    NifcWildfireClient.define_singleton_method(:new) { |*_args| nifc_fake }

    yield
  ensure
    WaDnrWildfireClient.singleton_class.remove_method(:new)
    NifcWildfireClient.singleton_class.remove_method(:new)
    WaDnrWildfireClient.singleton_class.alias_method(:new, :__orig_new)
    NifcWildfireClient.singleton_class.alias_method(:new, :__orig_new)
    WaDnrWildfireClient.singleton_class.remove_method(:__orig_new)
    NifcWildfireClient.singleton_class.remove_method(:__orig_new)
  end

  test "prefers DNR fire and enriches containment from nearby NIFC match" do
    dnr = [ {
      name: "Smith Fire",
      lat: 47.3,
      lon: -121.0,
      acres: 120.0,
      external_id: "1",
      source: "wadnr"
    } ]
    nifc = [ {
      name: "Smith Fire",
      lat: 47.31,
      lon: -121.01,
      acres: 125.0,
      percent_contained: 40.0,
      url: "https://example.com/smith",
      external_id: "IRWIN-1",
      source: "nifc",
      state: "WA"
    } ]

    stub_clients(dnr: dnr, nifc: nifc) do
      result = NearestWildfireResolver.new(lat: 47.3, lon: -122.2).call
      assert_equal "Smith Fire", result[:name]
      assert_equal 40.0, result[:percent_contained]
      assert_equal "https://example.com/smith", result[:url]
      assert_equal "wadnr+nifc", result[:source]
      assert result[:distance_mi] > 0
    end
  end

  test "falls back to nearest NIFC WA fire when DNR is empty" do
    nifc = [
      {
        name: "Far Fire",
        lat: 45.0,
        lon: -120.0,
        acres: 10.0,
        percent_contained: 10.0,
        url: "https://example.com/far",
        external_id: "2",
        source: "nifc",
        state: "OR"
      },
      {
        name: "Near Fire",
        lat: 47.4,
        lon: -122.1,
        acres: 5.0,
        percent_contained: 80.0,
        url: "https://example.com/near",
        external_id: "3",
        source: "nifc",
        state: "WA"
      }
    ]

    stub_clients(dnr: [], nifc: nifc) do
      result = NearestWildfireResolver.new(lat: 47.3, lon: -122.2).call
      assert_equal "Near Fire", result[:name]
      assert_equal 80.0, result[:percent_contained]
    end
  end
end
