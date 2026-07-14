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

    hours = ((end_time - start_time) / 1.hour).to_i + 1
    eta = (hours * BackfillAirNowPm25Job::TRICKLE_DELAY).inspect

    puts "Enqueueing AirNow PM2.5 backfill from #{end_time.utc.iso8601} backward to #{start_time.utc.iso8601}"
    puts "This queues ONE job that re-enqueues the previous hour after each run (~#{hours} hours, ~#{eta} wall clock)."
    puts "You will not see thousands of jobs in the queue — only the current run + one scheduled follow-up."
    BackfillAirNowPm25Job.perform_async(end_time.utc.iso8601, start_time.utc.iso8601)
    puts "Queued."
  end
end
