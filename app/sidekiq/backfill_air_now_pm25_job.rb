# frozen_string_literal: true

# Trickle-fetches one HourlyAQObs hour at a time for Auburn 29th St,
# then re-enqueues the next hour until `end_time` is reached.
class BackfillAirNowPm25Job
  include Sidekiq::Job

  sidekiq_options retry: 3

  TRICKLE_DELAY = 45.seconds

  # start_time / end_time: ISO8601 strings or Time-like
  def perform(start_time, end_time = nil)
    current = parse_time(start_time).utc.change(min: 0, sec: 0)
    finish = end_time.present? ? parse_time(end_time).utc.change(min: 0, sec: 0) : Time.current.utc.change(min: 0, sec: 0)

    return if current > finish

    reading = AirNowHourlyObsService.new.fetch_reading(current)
    Aqi.upsert_reading!(**reading) if reading

    next_hour = current + 1.hour
    return if next_hour > finish

    self.class.perform_in(TRICKLE_DELAY, next_hour.iso8601, finish.iso8601)
  end

  private

  def parse_time(value)
    return value if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)

    Time.iso8601(value.to_s)
  rescue ArgumentError
    Time.zone.parse(value.to_s)
  end
end
