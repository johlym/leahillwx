class UsgsEarthquakeApiService
  def initialize
    lat = ENV["LOCATION_LAT"]
    lon = ENV["LOCATION_LON"]
    @url = "https://earthquake.usgs.gov/fdsnws/event/1/query?limit=1&lat=#{lat}&lon=#{lon}&maxradiuskm=1000&format=geojson&nodata=204&minmag=2"
  end

  def get_latest_earthquake
    response = HTTParty.get(@url)
    data = JSON.parse(response.body)
    d = data["features"][0]
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
