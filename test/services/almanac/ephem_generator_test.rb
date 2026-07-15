require "test_helper"

class Almanac::EphemGeneratorTest < ActiveSupport::TestCase
  setup do
    @generator = Almanac::EphemGenerator.new
  end

  test "responds to public API methods" do
    %i[
      spk
      calculate_live_positions
      bsp_coverage
      generate_daily_entry
      generate_hourly_positions
      astronomical_seasons_for_year
      season_for_date
    ].each do |method|
      assert_respond_to @generator, method, "expected public method #{method}"
    end
  end

  test "astronomical_seasons_for_year returns season boundaries for 2024" do
    seasons = @generator.astronomical_seasons_for_year(2024)

    assert seasons.key?(:spring_equinox)
    assert seasons.key?(:summer_solstice)
    assert seasons.key?(:autumn_equinox)
    assert seasons.key?(:winter_solstice)

    assert_not_nil seasons[:spring_equinox]
    assert_equal 3, seasons[:spring_equinox].month
    assert_includes [ 19, 20, 21 ], seasons[:spring_equinox].day

    assert_not_nil seasons[:summer_solstice]
    assert_equal 6, seasons[:summer_solstice].month
    assert_includes [ 20, 21, 22 ], seasons[:summer_solstice].day
  end

  test "season_for_date returns expected season" do
    assert_equal :summer, @generator.season_for_date(Date.new(2024, 6, 21))
    assert_equal :winter, @generator.season_for_date(Date.new(2024, 1, 15))
    assert_equal :fall, @generator.season_for_date(Date.new(2024, 10, 1))
  end

  test "included math helpers remain available on generator" do
    assert_in_delta 0.0, @generator.revolution(360.0), 1e-10
    assert_in_delta 1.0, @generator.sind(90.0), 1e-10
    assert_in_delta 0.0, @generator.cosd(90.0), 1e-10

    jd = @generator.datetime_to_julian_date(Time.utc(2024, 1, 1, 12, 0, 0))
    assert_in_delta 2460311.0, jd, 0.01
    assert_equal Time.utc(2024, 1, 1, 12, 0, 0), @generator.jd_to_time(jd)
  end

  test "private BSP helpers remain callable via send for polynomial generator" do
    time = Time.utc(2024, 6, 21, 12, 0, 0)
    jd = @generator.send(:datetime_to_julian_date, time)

    sun_pos = @generator.send(:calculate_sun_position_bsp, jd)
    moon_pos = @generator.send(:calculate_moon_position_bsp, jd)

    assert sun_pos.key?(:azimuth)
    assert sun_pos.key?(:altitude)
    assert moon_pos.key?(:azimuth)
    assert moon_pos.key?(:altitude)
  end
end
