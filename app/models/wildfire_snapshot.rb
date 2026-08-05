# frozen_string_literal: true

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
class WildfireSnapshot < ApplicationRecord
  validates :lat, :lon, :distance_mi, :source, :fetched_at, presence: true
  validates :name, presence: true, if: :active?
  validates :active, inclusion: { in: [ true, false ] }

  def self.latest
    order(fetched_at: :desc).first
  end

  # Latest snapshot that represents a live fire (excludes empty refresh markers).
  def self.latest_active
    snap = latest
    snap if snap&.active?
  end
end
