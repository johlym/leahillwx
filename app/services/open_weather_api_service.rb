class OpenWeatherApiService
  def initialize
    @appid = ENV["OPENWEATHER_API_KEY"]
    @base_url = "https://api.openweathermap.org"
    @lat = ENV["LOCATION_LAT"]
    @lon = ENV["LOCATION_LON"]
    @exclude = "minutely"
    @units = "metric"
  end

  def retrieve_forecast
    endpoint_path = "/data/3.0/onecall"
    params = {
      "appid" => @appid,
      "lat" => @lat,
      "lon" => @lon,
      "exclude" => @exclude,
      "units" => @units
    }
    response = HTTParty.get(@base_url + endpoint_path, query: params)
    JSON.parse(response.body)
  end

  def retrieve_current
    endpoint_path = "/data/3.0/onecall"
    params = {
      "appid" => @appid,
      "lat" => @lat,
      "lon" => @lon,
      "exclude" => "minutely,hourly,daily,alerts",
      "units" => @units
    }
    response = HTTParty.get(@base_url + endpoint_path, query: params)
    JSON.parse(response.body)
  end

  def retrieve_aqi
    endpoint_path = "/data/2.5/air_pollution"
    params = {
      "appid" => @appid,
      "lat" => @lat,
      "lon" => @lon
    }
    response = HTTParty.get(@base_url + endpoint_path, query: params)
    JSON.parse(response.body)
  end
end
