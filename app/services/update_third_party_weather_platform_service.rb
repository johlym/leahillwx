class UpdateThirdPartyWeatherPlatformService
  SUPPORTED_SERVICES = [
    "weatherunderground",
    "pwsweather",
    "awekas",
    "weathercloud",
    "cwop"
  ].freeze

  def initialize(weather_measurement, service)
    @weather_measurement = weather_measurement
    @service = service

    raise ArgumentError, "Unsupported service: #{@service}" unless SUPPORTED_SERVICES.include?(@service)
  end

  def perform
    Rails.logger.info "Updating third party weather platform: #{@service}"

    send("update_#{@service}", @weather_measurement)

    Rails.logger.info "Update complete for: #{@service}"
  end

  def update_weatherunderground(measurement)
    # TODO: Implement update_weatherunderground
    # SAMPLE POST URL with data embedded: https://weatherstation.wunderground.com/weatherstation/updateweatherstation.php?ID=KCASANFR5&PASSWORD=XXXXXX&dateutc=2000-01-01+10%3A32%3A35&winddir=230&windspeedmph=12&windgustmph=12&tempf=70&rainin=0&baromin=29.1&dewptf=68.2&humidity=90&weather=&clouds=&softwaretype=vws%20versionxx&action=updateraw

    date_utc = measurement.reading_date_time.utc.strftime("%Y-%m-%d+%H:%M:%S")
    wind_dir = measurement.wind_dir
    wind_speed_mph = measurement.wind_speed_mph
    wind_gust_mph = measurement.wind_gust_mph
    temp_f = measurement.temperature_f
    rain_in = measurement.rain_rate_in
    barometer_in = measurement.barometer_abs_mmhg
    humidity = measurement.humidity
    dew_point_f = measurement.dew_point_f

    request_url = "https://weatherstation.wunderground.com/weatherstation/updateweatherstation.php"
    request_params = {
      ID: ENV["WU_STATION_ID"],
      PASSWORD: ENV["WU_STATION_KEY"],
      dateutc: date_utc,
      winddir: wind_dir,
      windspeedmph: wind_speed_mph,
      windgustmph: wind_gust_mph,
      tempf: temp_f,
      rainin: rain_in,
      baromin: barometer_in,
      dewptf: dew_point_f,
      humidity: humidity,
      weather: "",
      clouds: "",
      softwaretype: "lhwx",
      action: "updateraw"
  }
    wu_request = HTTParty.post(request_url, query: request_params)
    Rails.logger.info "Weather Underground response: #{wu_request.body}"
  end

  def update_pwsweather(measurement)
    # TODO: Implement update_pwsweather
  end

  def update_awekas(measurement)
    # TODO: Implement update_awekas
  end

  def update_weathercloud(measurement)
    # TODO: Implement update_weathercloud
  end

  def cwop(measurement)
    # TODO: Implement cwop
  end
end
