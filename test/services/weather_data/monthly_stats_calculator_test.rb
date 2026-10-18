require "test_helper"

class WeatherData::MonthlyStatsCalculatorTest < ActiveSupport::TestCase
  setup do
    @report = Report.create!(year: 2024, month: 1)
    @report.entries.create!(day: 1, mean_temp: 50.0, high_temp: 60.0, low_temp: 40.0, rain: 0.5,
                            mean_pressure: 1010.0, high_pressure: 1015.0, low_pressure: 1005.0)
    @report.entries.create!(day: 2, mean_temp: 55.0, high_temp: 65.0, low_temp: 45.0, rain: 0.3,
                            mean_pressure: 1012.0, high_pressure: 1020.0, low_pressure: 1008.0)
  end

  test "should calculate monthly mean temperature" do
    calculator = WeatherData::MonthlyStatsCalculator.new(@report)
    calculator.calculate

    @report.reload
    assert_equal 52.5, @report.month_mean_temp
  end

  test "should find month high temperature" do
    calculator = WeatherData::MonthlyStatsCalculator.new(@report)
    calculator.calculate

    @report.reload
    assert_equal 65.0, @report.month_high_temp
    assert_equal 2, @report.month_high_temp_day
  end

  test "should find month low temperature" do
    calculator = WeatherData::MonthlyStatsCalculator.new(@report)
    calculator.calculate

    @report.reload
    assert_equal 40.0, @report.month_low_temp
    assert_equal 1, @report.month_low_temp_day
  end

  test "should calculate total rain" do
    calculator = WeatherData::MonthlyStatsCalculator.new(@report)
    calculator.calculate

    @report.reload
    assert_equal 0.8, @report.total_rain
  end

  test "should calculate monthly mean pressure" do
    calculator = WeatherData::MonthlyStatsCalculator.new(@report)
    calculator.calculate

    @report.reload
    assert_equal 1011.0, @report.month_mean_pressure
    assert_equal 1020.0, @report.month_high_pressure
    assert_equal 2, @report.month_high_pressure_day
    assert_equal 1005.0, @report.month_low_pressure
    assert_equal 1, @report.month_low_pressure_day
  end

  test "should handle report with no entries" do
    empty_report = Report.create!(year: 2024, month: 2)
    calculator = WeatherData::MonthlyStatsCalculator.new(empty_report)

    assert_nothing_raised do
      calculator.calculate
    end
  end
end
