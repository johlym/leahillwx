# frozen_string_literal: true

class DownloadNearestWildfireJob
  include Sidekiq::Job

  def perform(*_args)
    fire = NearestWildfireResolver.new.call
    if fire.nil?
      Rails.logger.info("No active wildfires found for nearest-wildfire snapshot")
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
      fetched_at: Time.current
    )
  rescue HttpClient::RequestError => e
    Rails.logger.warn("Nearest wildfire download failed: #{e.message}")
  end
end

