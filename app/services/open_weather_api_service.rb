class OpenWeatherApiService
  def initialize
    @appid = ENV["OPENWEATHER_API_KEY"]
    @base_url = "https://api.openweathermap.org/data/3.0/onecall"
    @lat = ENV["LOCATION_LAT"]
    @lon = ENV["LOCATION_LON"]
    @exclude = "current,minutely,hourly"
    @units = "metric"
  end

  def retrieve_forecast
    params = {
      "appid" => @appid,
      "lat" => @lat,
      "lon" => @lon,
      "exclude" => @exclude,
      "units" => @units
    }
    response = HTTParty.get(@base_url, query: params)
    JSON.parse(response.body)
  end
end
