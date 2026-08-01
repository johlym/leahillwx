# frozen_string_literal: true

class DownloadLatestEarthquakeJob
  include Sidekiq::Job

  def perform(*_args)
    eq = UsgsEarthquakeClient.new.get_latest_earthquake
    return if eq.nil?

    Rails.logger.info(eq)
    lat = eq[:lat]
    lon = eq[:lon]
    lat2 = ENV["LOCATION_LAT"].to_i
    lon2 = ENV["LOCATION_LON"].to_i
    unit = :mi
    eq[:distance] = GeoDistance.distance(lat, lon, lat2, lon2, unit: unit)

    earthquake = Earthquake.find_or_initialize_by(usgs_id: eq[:usgs_id])

    earthquake.revised = true if earthquake.persisted?

    earthquake.assign_attributes(eq.except(:usgs_id))
    earthquake.save!
  rescue HttpClient::RequestError => e
    Rails.logger.warn("Earthquake download failed: #{e.message}")
  end
end
