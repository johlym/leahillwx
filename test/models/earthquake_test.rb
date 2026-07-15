# == Schema Information
#
# Table name: earthquakes
#
#  id           :bigint           not null, primary key
#  depth        :float            not null
#  distance     :float            not null
#  eventtime    :datetime         not null
#  last_updated :datetime         not null
#  lat          :float            not null
#  lon          :float            not null
#  magnitude    :float            not null
#  place        :string           not null
#  revised      :boolean          default(FALSE), not null
#  url          :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  usgs_id      :string           not null
#
# Indexes
#
#  index_earthquakes_on_eventtime  (eventtime)
#  index_earthquakes_on_usgs_id    (usgs_id) UNIQUE
#
require "test_helper"

class EarthquakeTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
