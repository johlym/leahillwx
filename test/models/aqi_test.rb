# == Schema Information
#
# Table name: aqis
#
#  id          :bigint           not null, primary key
#  co          :float
#  epa_aqi     :integer
#  nh3         :float
#  no          :float
#  no2         :float
#  o3          :float
#  observed_at :datetime         not null
#  pm10        :float
#  pm2_5       :float            not null
#  so2         :float
#  source      :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_aqis_on_observed_at  (observed_at) UNIQUE
#  index_aqis_on_source       (source)
#
require "test_helper"

class AqiTest < ActiveSupport::TestCase
  test "epa_aqi_from_pm25 maps good range" do
    assert_equal 0, Aqi.epa_aqi_from_pm25(0)
    assert_in_delta 42, Aqi.epa_aqi_from_pm25(10.0), 5
  end

  test "epa_category_for treats 301+ as Hazardous" do
    assert_equal "Good", Aqi.epa_category_for(25)
    assert_equal "Hazardous", Aqi.epa_category_for(301)
    assert_equal "Hazardous", Aqi.epa_category_for(600)
  end

  test "aqi_marker_position_for uses thirds for 0-100, 100-200, 200-500" do
    assert_in_delta 0.0, Aqi.aqi_marker_position_for(0), 0.05
    assert_in_delta 16.7, Aqi.aqi_marker_position_for(50), 0.2
    assert_in_delta 33.3, Aqi.aqi_marker_position_for(100), 0.2
    assert_in_delta 50.0, Aqi.aqi_marker_position_for(150), 0.2
    assert_in_delta 66.7, Aqi.aqi_marker_position_for(200), 0.2
    assert_in_delta 77.8, Aqi.aqi_marker_position_for(300), 0.2
    assert_in_delta 100.0, Aqi.aqi_marker_position_for(500), 0.05
  end

  test "upsert_reading! creates and does not let openweather overwrite airnow" do
    hour = Time.utc(2026, 7, 13, 23, 0, 0)

    airnow = Aqi.upsert_reading!(
      observed_at: hour,
      pm2_5: 2.1,
      epa_aqi: 11,
      source: "airnow"
    )
    assert_equal "airnow", airnow.source
    assert_equal 11, airnow.epa_aqi

    result = Aqi.upsert_reading!(
      observed_at: hour,
      pm2_5: 9.9,
      source: "openweather",
      co: 100.0
    )

    assert_equal airnow.id, result.id
    assert_equal 2.1, result.reload.pm2_5
    assert_equal "airnow", result.source
  end

  test "upsert_reading! allows airnow to overwrite openweather" do
    hour = Time.utc(2026, 7, 13, 22, 0, 0)

    Aqi.upsert_reading!(observed_at: hour, pm2_5: 5.0, source: "openweather")
    updated = Aqi.upsert_reading!(
      observed_at: hour,
      pm2_5: 2.1,
      epa_aqi: 11,
      source: "airnow"
    )

    assert_equal "airnow", updated.source
    assert_equal 2.1, updated.pm2_5
    assert_equal 11, updated.epa_aqi
  end

  test "stale? is true when older than 8 hours" do
    reading = Aqi.upsert_reading!(
      observed_at: 9.hours.ago,
      pm2_5: 3.0,
      source: "openweather"
    )
    assert reading.stale?
  end

  test "daily_averages groups by Pacific date" do
    zone = ActiveSupport::TimeZone["America/Los_Angeles"]
    day = zone.local(2026, 7, 13, 10)
    Aqi.upsert_reading!(observed_at: day.utc, pm2_5: 2.0, source: "airnow", epa_aqi: 10)
    Aqi.upsert_reading!(observed_at: (day + 1.hour).utc, pm2_5: 4.0, source: "airnow", epa_aqi: 20)

    series = Aqi.daily_averages(from: day.beginning_of_day, to: day.end_of_day)
    assert_equal 1, series.size
    assert_equal Date.new(2026, 7, 13), series.first[:date]
    assert_in_delta 3.0, series.first[:pm2_5], 0.01
    assert_in_delta 15.0, series.first[:epa_aqi], 0.01
  end
end
