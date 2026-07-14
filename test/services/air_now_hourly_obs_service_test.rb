# frozen_string_literal: true

require "test_helper"

class AirNowHourlyObsServiceTest < ActiveSupport::TestCase
  SAMPLE = <<~CSV
    "AQSID","SiteName","Status","EPARegion","Latitude","Longitude","Elevation","GMTOffset","CountryCode","StateName","ValidDate","ValidTime","DataSource","ReportingArea_PipeDelimited","OZONE_AQI","PM10_AQI","PM25_AQI","NO2_AQI","OZONE_Measured","PM10_Measured","PM25_Measured","NO2_Measured","PM25","PM25_Unit","OZONE","OZONE_Unit","NO2","NO2_Unit","CO","CO_Unit","SO2","SO2_Unit","PM10","PM10_Unit"
    "840530330047","Auburn 29th St","Active","R10","47.2814","-122.2233","31.7","-8","US","WA","07/13/2026","00:00","Washington Department of Ecology","Seattle-Bellevue-Kent Valley","","","11","","0","0","1","0","2.1","UG/M3","","","","","","","","","",""
    "840530330089","Auburn M St SE","Inactive","R10","47.2875","-122.2144","4.0","-8","US","WA","07/13/2026","00:00","Washington Department of Ecology","","","","","","0","0","1","0","","","","","","","","","","","",""
  CSV

  test "parse_reading extracts Auburn 29th St PM2.5" do
    service = AirNowHourlyObsService.new(aqsid: "840530330047")
    reading = service.parse_reading(SAMPLE)

    assert_equal Time.utc(2026, 7, 13, 0, 0, 0), reading[:observed_at]
    assert_in_delta 2.1, reading[:pm2_5], 0.001
    assert_equal 11, reading[:epa_aqi]
    assert_equal "airnow", reading[:source]
  end

  test "url_for builds HourlyAQObs path" do
    service = AirNowHourlyObsService.new
    url = service.url_for(Time.utc(2026, 7, 13, 0, 0, 0))
    assert_includes url, "/airnow/2026/20260713/HourlyAQObs_2026071300.dat"
  end
end
