# frozen_string_literal: true

# == Schema Information
#
# Table name: wildfire_snapshots
#
#  id                :bigint           not null, primary key
#  acres             :float
#  distance_mi       :float            not null
#  fetched_at        :datetime         not null
#  lat               :float            not null
#  lon               :float            not null
#  name              :string           not null
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
  validates :name, :lat, :lon, :distance_mi, :source, :fetched_at, presence: true

  def self.latest
    order(fetched_at: :desc).first
  end
end
