# frozen_string_literal: true

require "test_helper"

class SeaLevelPressureTest < ActiveSupport::TestCase
  test "NWS altimeter at 416 ft matches nearby 1019 hPa from 29.63 inHg station" do
    station_hpa = 29.63 * SeaLevelPressure::HPA_PER_INHG

    slp = SeaLevelPressure.hpa(station_hpa, elevation_ft: 416)

    assert_in_delta 1018.6, slp, 0.05
    assert_equal 1019, slp.round
  end

  test "relative 29.54 inHg is the under-reported 1000 hPa console value" do
    relative_hpa = 29.54 * SeaLevelPressure::HPA_PER_INHG

    assert_in_delta 1000.3, relative_hpa, 0.05
    assert_equal 1000, relative_hpa.round
  end

  test "zero elevation leaves station pressure unchanged" do
    assert_in_delta 1003.4, SeaLevelPressure.hpa(1003.4, elevation_ft: 0), 0.000001
  end

  test "nil and non-positive station pressure are not reduced" do
    assert_nil SeaLevelPressure.hpa(nil, elevation_ft: 416)
    assert_equal 0, SeaLevelPressure.hpa(0, elevation_ft: 416)
    assert_equal(-1, SeaLevelPressure.hpa(-1, elevation_ft: 416))
  end

  test "QFF at 416 ft is about 18.5 hPa above the console relative value" do
    station_hpa = 29.63 * SeaLevelPressure::HPA_PER_INHG
    relative_hpa = 29.54 * SeaLevelPressure::HPA_PER_INHG

    qff = SeaLevelPressure.qff_hpa(station_hpa, temp_c: 18.0, elevation_ft: 416)
    qc_delta = relative_hpa - qff

    assert_in_delta 1018.4, qff, 0.2
    assert_in_delta(-18.5, qc_delta, 0.5)
  end

  test "QFF equals station pressure at sea level" do
    assert_in_delta 1003.4, SeaLevelPressure.qff_hpa(1003.4, temp_c: 18.0, elevation_ft: 0), 0.000001
  end

  test "qff_sql is identity at sea level and the QFF formula aloft" do
    assert_equal "barometer_abs", SeaLevelPressure.qff_sql(elevation_ft: 0)
    assert_match(/EXP\(/, SeaLevelPressure.qff_sql(elevation_ft: 416))
  end

  test "reads LOCATION_ELEVATION_FT when elevation is omitted" do
    previous = ENV["LOCATION_ELEVATION_FT"]
    ENV["LOCATION_ELEVATION_FT"] = "416"

    slp = SeaLevelPressure.hpa(29.63 * SeaLevelPressure::HPA_PER_INHG)

    assert_in_delta 1018.6, slp, 0.05
  ensure
    previous.nil? ? ENV.delete("LOCATION_ELEVATION_FT") : ENV["LOCATION_ELEVATION_FT"] = previous
  end
end
