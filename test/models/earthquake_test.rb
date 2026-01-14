# == Schema Information
#
# Table name: earthquakes
#
#  id         :bigint           not null, primary key
#  depth      :float
#  distance   :float
#  eventtime  :datetime
#  lat        :float
#  lon        :float
#  magnitude  :float
#  place      :string
#  url        :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
require "test_helper"

class EarthquakeTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
