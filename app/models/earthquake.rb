# == Schema Information
#
# Table name: earthquakes
#
#  id           :bigint           not null, primary key
#  depth        :float
#  distance     :float
#  eventtime    :datetime
#  last_updated :datetime
#  lat          :float
#  lon          :float
#  magnitude    :float
#  place        :string
#  revised      :boolean          default(FALSE)
#  url          :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  usgs_id      :string
#
# Indexes
#
#  index_earthquakes_on_eventtime  (eventtime)
#  index_earthquakes_on_usgs_id    (usgs_id) UNIQUE
#
class Earthquake < ApplicationRecord
  validates :magnitude, :place, :eventtime, :last_updated, :url, :lat, :lon, :depth, :distance, :usgs_id, presence: true
end
