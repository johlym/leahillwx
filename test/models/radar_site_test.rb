# frozen_string_literal: true

require "test_helper"

class RadarSiteTest < ActiveSupport::TestCase
  test "all returns the three PNW NEXRAD sites" do
    ids = RadarSite.all.map(&:id)
    assert_equal %w[KATX KRTX KLGX], ids
  end

  test "sites expose IEM sector codes without leading K" do
    assert_equal %w[ATX RTX LGX], RadarSite.all.map(&:sector)
  end

  test "find is case-insensitive" do
    site = RadarSite.find("katx")
    assert_equal "KATX", site.id
    assert_equal "Camano Island", site.name
    assert_in_delta 48.194611, site.lat, 0.0001
    assert_in_delta(-122.49569, site.lon, 0.0001)
  end

  test "find returns nil for unknown ids" do
    assert_nil RadarSite.find("KFAX")
    assert_nil RadarSite.find(nil)
  end

  test "as_json is Stimulus-ready with string keys" do
    payload = RadarSite.as_json
    assert_equal 3, payload.size

    katx = payload.find { |row| row[:id] == "KATX" }
    assert_equal "ATX", katx[:sector]
    assert_equal "Camano Island", katx[:name]
    assert_kind_of Float, katx[:lat]
    assert_kind_of Float, katx[:lon]
  end

  test "Portland and Langley Hill coordinates are west of the Cascades" do
    rtx = RadarSite.find("KRTX")
    lgx = RadarSite.find("KLGX")

    assert_operator rtx.lat, :<, 46
    assert_operator rtx.lon, :<, -122
    assert_operator lgx.lat, :>, 47
    assert_operator lgx.lon, :<, -124
  end
end
