# == Schema Information
#
# Table name: weather_measurements
#
#  id                :bigint           not null, primary key
#  barometer_abs     :float            not null
#  barometer_rel     :float            not null
#  gust_speed        :float            not null
#  humidity          :integer          not null
#  light             :float            not null
#  rain_day          :float            default(0.0)
#  rain_rate         :float            not null
#  reading_date_time :datetime         not null
#  temperature       :float            not null
#  uv                :integer          not null
#  uvi               :float            not null
#  wind_dir          :integer          not null
#  wind_speed        :float            not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_weather_measurements_on_reading_date_time  (reading_date_time)
#
require "test_helper"

class WeatherMeasurementTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
