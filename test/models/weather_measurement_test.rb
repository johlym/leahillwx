# == Schema Information
#
# Table name: weather_measurements
#
#  id                :bigint           not null, primary key
#  barometer_abs     :float            not null
#  barometer_rel     :float            not null
#  dew_point         :float            default(0.0)
#  gust_speed        :float            not null
#  heat_index        :float            default(0.0)
#  humidity          :integer          not null
#  light             :float            not null
#  rain_day          :float            default(0.0)
#  rain_rate         :float            not null
#  reading_date_time :datetime         not null
#  temperature       :float            not null
#  uv                :integer          not null
#  uvi               :float            not null
#  wind_chill        :float            default(0.0)
#  wind_dir          :integer          not null
#  wind_speed        :float            not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
require "test_helper"

class WeatherMeasurementTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
