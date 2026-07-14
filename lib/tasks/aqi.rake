# frozen_string_literal: true

namespace :aqi do
  desc "Trickle-backfill Auburn 29th St PM2.5 from AirNow HourlyAQObs files. " \
       "Usage: rake aqi:backfill[2022-01-01,2026-07-13] (defaults: start=2022-01-01, end=now)"
  task :backfill, [ :start, :end ] => :environment do |_t, args|
    start_time = Time.zone.parse(args[:start].presence || "2022-01-01").beginning_of_hour
    end_time = if args[:end].present?
      Time.zone.parse(args[:end]).beginning_of_hour
    else
      Time.current.beginning_of_hour
    end

    if start_time > end_time
      abort "start (#{start_time}) must be <= end (#{end_time})"
    end

    puts "Enqueueing AirNow PM2.5 backfill from #{start_time.utc.iso8601} to #{end_time.utc.iso8601}"
    BackfillAirNowPm25Job.perform_async(start_time.utc.iso8601, end_time.utc.iso8601)
    puts "Queued. Sidekiq will trickle one hour every ~45s."
  end
end
