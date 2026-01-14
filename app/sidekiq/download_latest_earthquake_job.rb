class DownloadLatestEarthquakeJob
  include Sidekiq::Job

  def perform(*args)
    eq = UsgsEarthquakeApiService.new.get_latest_earthquake
    lat = eq[:lat]
    lon = eq[:lon]
    lat2 = ENV["LOCATION_LAT"].to_i
    lon2 = ENV["LOCATION_LON"].to_i
    unit = :mi
    eq[:distance] = GeoDistanceService.distance(lat, lon, lat2, lon2, unit: unit)
    eq = Earthquake.find_or_create_by(eq)
  end
end
