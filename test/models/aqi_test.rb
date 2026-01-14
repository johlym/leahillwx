# == Schema Information
#
# Table name: aqis
#
#  id         :bigint           not null, primary key
#  co         :float
#  nh3        :float
#  no         :float
#  no2        :float
#  o3         :float
#  pm10       :float
#  pm2_5      :float
#  so2        :float
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
require "test_helper"

class AqiTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
