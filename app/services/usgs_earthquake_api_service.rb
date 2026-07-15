class UsgsEarthquakeApiService
  TIMEOUT_SECONDS = 10

  def initialize
    lat = ENV["LOCATION_LAT"]
    lon = ENV["LOCATION_LON"]
    @url = "https://earthquake.usgs.gov/fdsnws/event/1/query?limit=1&lat=#{lat}&lon=#{lon}&maxradiuskm=1000&format=geojson&nodata=204&minmag=2"
  end

  # Returns a hash of earthquake attributes, or nil when USGS has no matching features.
  def get_latest_earthquake
    response = HttpClient.get(@url, timeout: TIMEOUT_SECONDS)
    return nil if response.code == 204 || response.body.blank?

    data = JSON.parse(response.body)
    features = data["features"]
    return nil if features.blank?

    d = features[0]
    p = d["properties"]
    g = d["geometry"]
    {
      magnitude: p["mag"],
      place: p["place"],
      eventtime: Time.at(p["time"] / 1000),
      last_updated: Time.at(p["updated"] / 1000),
      url: p["url"],
      lat: g["coordinates"][1],
      lon: g["coordinates"][0],
      depth: g["coordinates"][2],
      usgs_id: d["id"]
    }
  end
end
