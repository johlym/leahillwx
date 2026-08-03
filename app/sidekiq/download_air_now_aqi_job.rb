# frozen_string_literal: true

# Pulls the latest Auburn (or AIRNOW_AQSID) PM2.5 / EPA AQI readings from
# AirNow HourlyAQObs files. Files often lag the clock by 1–2 hours, so each
# run walks back LOOKBACK_HOURS and upserts whatever is available.
class DownloadAirNowAqiJob
  include Sidekiq::Job

  LOOKBACK_HOURS = 6

  def perform(*_args)
    service = AirNowHourlyObservation.new
    newest = Time.current.utc.change(min: 0, sec: 0)
    upserted = 0

    LOOKBACK_HOURS.times do |offset|
      hour = newest - offset.hours
      reading = fetch_hour(service, hour)
      next if reading.nil?

      Aqi.upsert_reading!(**reading)
      upserted += 1
      Rails.logger.info(
        "[DownloadAirNowAqiJob] upserted #{reading[:observed_at].iso8601} " \
        "pm2_5=#{reading[:pm2_5]} aqi=#{reading[:epa_aqi]}"
      )
    end

    Rails.logger.info("[DownloadAirNowAqiJob] no AirNow PM2.5 in last #{LOOKBACK_HOURS}h") if upserted.zero?
  end

  private

  def fetch_hour(service, hour)
    service.fetch_reading(hour)
  rescue StandardError => e
    Rails.logger.warn("[DownloadAirNowAqiJob] fetch failed for #{hour.iso8601}: #{e.message}")
    nil
  end
end
