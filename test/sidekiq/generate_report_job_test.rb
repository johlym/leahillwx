require "test_helper"

class GenerateReportJobTest < ActiveSupport::TestCase
  test "should default to yesterday when no date provided" do
    job = GenerateReportJob.new

    assert_difference "ReportEntry.count", 1 do
      job.perform
    end

    entry = ReportEntry.last
    assert_equal Date.yesterday.day, entry.day
  end

  test "should process specific date when provided" do
    date = Date.parse("2024-01-15")
    job = GenerateReportJob.new

    assert_difference "ReportEntry.count", 1 do
      job.perform(date)
    end

    entry = ReportEntry.last
    assert_equal 15, entry.day
  end

  test "should handle date string parameter" do
    job = GenerateReportJob.new

    assert_nothing_raised do
      job.perform("2024-01-15")
    end
  end

  test "should create report if it doesn't exist" do
    date = Date.parse("2024-02-15")
    job = GenerateReportJob.new

    assert_difference "Report.count", 1 do
      job.perform(date)
    end

    report = Report.find_by(year: 2024, month: 2)
    assert_not_nil report
  end
end
