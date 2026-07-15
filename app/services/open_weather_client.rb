class OpenWeatherClient
  class RequestError < HttpClient::RequestError; end

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
    get_json(endpoint_path, params)
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
    get_json(endpoint_path, params)
  end

  def retrieve_aqi
    endpoint_path = "/data/2.5/air_pollution"
    params = {
      "appid" => @appid,
      "lat" => @lat,
      "lon" => @lon
    }
    get_json(endpoint_path, params)
  end

  private

  def get_json(endpoint_path, params)
    HttpClient.get_json(@base_url + endpoint_path, query: params)
  rescue HttpClient::RequestError => e
    raise RequestError, e.message
  end
end

OpenWeatherApiService = OpenWeatherClient
