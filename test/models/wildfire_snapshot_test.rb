# frozen_string_literal: true

require "test_helper"

# == Schema Information
#
# Table name: wildfire_snapshots
#
#  id                :bigint           not null, primary key
#  acres             :float
#  active            :boolean          default(TRUE), not null
#  distance_mi       :float            not null
#  fetched_at        :datetime         not null
#  lat               :float            not null
#  lon               :float            not null
#  name              :string
#  percent_contained :float
#  source            :string           not null
#  url               :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  external_id       :string
#
# Indexes
#
#  index_wildfire_snapshots_on_fetched_at  (fetched_at)
#
class WildfireSnapshotTest < ActiveSupport::TestCase
  test "latest_active ignores empty refresh markers" do
    WildfireSnapshot.create!(
      name: "Old Fire",
      lat: 47.0,
      lon: -122.0,
      distance_mi: 10,
      source: "wadnr",
      active: true,
      fetched_at: 1.hour.ago
    )
    WildfireSnapshot.create!(
      name: nil,
      lat: 47.3,
      lon: -122.2,
      distance_mi: 0,
      source: "none",
      active: false,
      fetched_at: Time.current
    )

    assert_nil WildfireSnapshot.latest_active
    assert_equal "none", WildfireSnapshot.latest.source
  end

  test "latest_active returns the newest live fire" do
    WildfireSnapshot.create!(
      name: "Near Fire",
      lat: 47.0,
      lon: -122.0,
      distance_mi: 12,
      source: "wadnr",
      active: true,
      fetched_at: Time.current
    )

    assert_equal "Near Fire", WildfireSnapshot.latest_active.name
  end
end
