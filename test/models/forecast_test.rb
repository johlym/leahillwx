# == Schema Information
#
# Table name: forecasts
#
#  id         :bigint           not null, primary key
#  forecast   :jsonb
#  interval   :string           default("daily"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_forecasts_on_interval_and_created_at  (interval,created_at DESC)
#
require "test_helper"

class ForecastTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
