# frozen_string_literal: true

if ENV["COVERAGE"] == "1"
  require "simplecov"
  SimpleCov.start "rails" do
    enable_coverage :branch
    skip "/test/"
    skip "/config/"
    skip "/vendor/"
  end
end

ENV["RAILS_ENV"] ||= "test"
# Tests treat stored hPa as already at the reported elevation unless a case
# sets LOCATION_ELEVATION_FT. Production defaults to 416 ft (Leahill).
ENV["LOCATION_ELEVATION_FT"] ||= "0"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Coverage runs single-process so SimpleCov merges cleanly.
    if ENV["COVERAGE"] == "1"
      parallelize(workers: 1)
    else
      parallelize(workers: :number_of_processors)
    end

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # TotalCount lives in Redis; transactional fixtures roll back Postgres but not
    # Redis, so clear the per-worker key before every test to avoid drift.
    setup do
      WeatherMeasurements::TotalCount.clear!
    end
  end
end
