# frozen_string_literal: true

# Trickle-fetches one HourlyAQObs hour at a time for Auburn 29th St,
# walking backward from `current_time` until `oldest_time` is reached.
class BackfillAirNowPm25Job
  include Sidekiq::Job

  sidekiq_options retry: 3

  TRICKLE_DELAY = 45.seconds

  # current_time / oldest_time: ISO8601 strings or Time-like
  # Starts at current_time (newest) and decrements one hour per run.
  def perform(current_time, oldest_time = nil)
    current = parse_time(current_time).utc.change(min: 0, sec: 0)
    oldest = if oldest_time.present?
      parse_time(oldest_time).utc.change(min: 0, sec: 0)
    else
      Time.zone.parse("2022-01-01").utc.change(min: 0, sec: 0)
    end

    return if current < oldest

    reading = AirNowHourlyObsService.new.fetch_reading(current)
    if reading
      Aqi.upsert_reading!(**reading)
      Rails.logger.info("[BackfillAirNowPm25Job] upserted #{current.iso8601} pm2_5=#{reading[:pm2_5]} aqi=#{reading[:epa_aqi]}")
    else
      Rails.logger.info("[BackfillAirNowPm25Job] no PM2.5 for #{current.iso8601} (skipping)")
    end

    prev_hour = current - 1.hour
    return if prev_hour < oldest

    # One scheduled follow-up only — do not bulk-enqueue the whole range.
    self.class.perform_in(TRICKLE_DELAY, prev_hour.iso8601, oldest.iso8601)
  end

  private

  def parse_time(value)
    return value if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)

    Time.iso8601(value.to_s)
  rescue ArgumentError
    Time.zone.parse(value.to_s)
  end
end
