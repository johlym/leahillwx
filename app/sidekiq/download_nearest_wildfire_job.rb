# frozen_string_literal: true

class DownloadNearestWildfireJob
  include Sidekiq::Job

  def perform(*_args)
    fire = NearestWildfireResolver.new.call
    if fire.nil?
      Rails.logger.info("No active wildfires found for nearest-wildfire snapshot")
      persist_empty_snapshot
      return
    end

    WildfireSnapshot.create!(
      name: fire[:name],
      lat: fire[:lat],
      lon: fire[:lon],
      distance_mi: fire[:distance_mi],
      acres: fire[:acres],
      percent_contained: fire[:percent_contained],
      url: fire[:url],
      source: fire[:source],
      external_id: fire[:external_id],
      active: true,
      fetched_at: Time.current
    )
  rescue HttpClient::RequestError => e
    Rails.logger.warn("Nearest wildfire download failed: #{e.message}")
  end

  private

  # Record a freshness check with no live fire so the card clears instead of
  # keeping a stale nearest-fire snapshot forever.
  def persist_empty_snapshot
    WildfireSnapshot.create!(
      name: nil,
      lat: ENV.fetch("LOCATION_LAT").to_f,
      lon: ENV.fetch("LOCATION_LON").to_f,
      distance_mi: 0,
      source: "none",
      active: false,
      fetched_at: Time.current
    )
  end
end
