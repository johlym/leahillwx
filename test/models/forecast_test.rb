# == Schema Information
#
# Table name: forecasts
#
#  id         :bigint           not null, primary key
#  forecast   :jsonb
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
require "test_helper"

class ForecastTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
