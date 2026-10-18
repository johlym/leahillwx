# frozen_string_literal: true

require "test_helper"

class TrendsAnalyzerTest < ActiveSupport::TestCase
  setup do
    report = Report.create!(year: 2024, month: 1, month_mean_pressure: 1010.0)
    report.entries.create!(day: 1, mean_temp: 10.0, high_temp: 15.0, low_temp: 5.0, mean_pressure: 1012.0)
    report.entries.create!(day: 2, mean_temp: 12.0, high_temp: 16.0, low_temp: 6.0, mean_pressure: 1008.0)
  end

  test "yoy_series includes monthly mean pressure" do
    series = TrendsAnalyzer.new(year: 2024).yoy_series
    dataset = series[:datasets].find { |d| d[:year] == 2024 }

    assert_equal 1010.0, dataset[:pressure_mean][0]
  end

  test "rolling_series includes pressure rolling means" do
    rolling = TrendsAnalyzer.new(year: 2024).rolling_series

    assert_equal 3, rolling[:pressures].length
    assert_includes rolling[:pressures].map { |s| s[:label] }, "30-day mean pressure"
    assert rolling[:pressures].all? { |s| s[:data].any? }
  end
end
