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
    # PWSWeather uses the Weather Underground protocol
    # Documentation: http://wiki.wunderground.com/index.php/PWS_-_Upload_Protocol

    date_utc = measurement.reading_date_time.utc.strftime("%Y-%m-%d+%H:%M:%S")
    wind_dir = measurement.wind_dir
    wind_speed_mph = measurement.wind_speed_mph
    wind_gust_mph = measurement.wind_gust_mph
    temp_f = measurement.temperature_f
    rain_in = measurement.rain_rate_in
    barometer_in = measurement.barometer_abs_mmhg
    humidity = measurement.humidity
    dew_point_f = measurement.dew_point_f

    request_url = "https://www.pwsweather.com/pwsupdate/pwsupdate.php"
    request_params = {
      ID: ENV["PWS_STATION_ID"],
      PASSWORD: ENV["PWS_STATION_KEY"],
      dateutc: date_utc,
      winddir: wind_dir,
      windspeedmph: wind_speed_mph,
      windgustmph: wind_gust_mph,
      tempf: temp_f,
      rainin: rain_in,
      baromin: barometer_in,
      dewptf: dew_point_f,
      humidity: humidity,
      softwaretype: "lhwx",
      action: "updateraw"
    }

    pws_request = HTTParty.post(request_url, query: request_params)
    Rails.logger.info "PWSWeather response: #{pws_request.body}"
  end

  def update_awekas(measurement)
    # AWEKAS API uses semicolon-separated values
    # Documentation: Based on weewx implementation at
    # https://github.com/weewx/weewx/blob/master/src/weewx/restx.py#L1608

    # Convert password to MD5 hash
    require "digest"
    password_hash = Digest::MD5.hexdigest(ENV["AWEKAS_USERNAME"])

    # Format timestamp in UTC
    time_utc = measurement.reading_date_time.utc
    date_str = time_utc.strftime("%d.%m.%Y")
    time_str = time_utc.strftime("%H:%M")

    # Get values in metric units (AWEKAS expects metric)
    temp_c = measurement.temperature
    humidity = measurement.humidity
    barometer_hpa = measurement.barometer_rel
    daily_rain_mm = (measurement.rain_day * 10).round(1)  # mm * 10 as per AWEKAS spec
    wind_speed_kmh = (measurement.wind_speed * 3.6).round(1)  # m/s to km/h
    wind_dir = measurement.wind_dir
    wind_gust_kmh = (measurement.gust_speed * 3.6).round(1)  # m/s to km/h
    solar_radiation = measurement.light
    uv_index = measurement.uvi
    rain_rate_mmh = (measurement.rain_rate * 10).round(1)  # mm/h * 10 as per AWEKAS spec

    # Assemble values array in AWEKAS order
    values = [
      ENV["AWEKAS_PASSWORD"],
      password_hash,
      date_str,
      time_str,
      temp_c,
      humidity,
      barometer_hpa,
      daily_rain_mm,
      wind_speed_kmh,
      wind_dir,
      "",  # weather condition
      "",  # warning text
      "",  # snow height
      "en",  # language
      "",  # tendency
      wind_gust_kmh,
      solar_radiation,
      uv_index,
      "",  # brightness in lux
      "",  # sunshine hours
      "",  # soil temperature
      rain_rate_mmh,
      "lhwx",  # software type
      ENV["LOCATION_LON"],
      ENV["LOCATION_LAT"]
    ]

    # Join with semicolons
    val_string = values.join(";")

    request_url = "https://data.awekas.at/get.php"
    awekas_request = HTTParty.get(request_url, query: { val: val_string })
    Rails.logger.info "AWEKAS response: #{awekas_request.body}"
  end

  def update_weathercloud(measurement)
    # WeatherCloud API v01
    # Documentation: Based on weewx-wcloud implementation at
    # https://github.com/matthewwall/weewx-wcloud
    # Note: WeatherCloud expects values in metric with specific multipliers

    # Base parameters (required)
    request_url = "http://api.weathercloud.net/v01/set"
    params = {
      wid: ENV["WEATHERCLOUD_DEVICE_ID"],
      key: ENV["WEATHERCLOUD_DEVICE_KEY"]
    }

    # Temperature and humidity (C * 10, percent)
    params[:temp] = (measurement.temperature * 10).round(0) if measurement.temperature
    params[:hum] = measurement.humidity.round(0) if measurement.humidity
    params[:tempin] = (measurement.temperature * 10).round(0) if measurement.temperature  # indoor not available, using outdoor

    # Wind (m/s * 10, degrees)
    params[:wspd] = (measurement.wind_speed * 10).round(0) if measurement.wind_speed
    params[:wdir] = measurement.wind_dir.round(0) if measurement.wind_dir
    params[:wspdhi] = (measurement.gust_speed * 10).round(0) if measurement.gust_speed

    # Barometric pressure (hPa * 10)
    params[:bar] = (measurement.barometer_rel * 10).round(0) if measurement.barometer_rel

    # Rain (mm * 10, mm/hr * 10)
    params[:rain] = (measurement.rain_day * 10).round(0) if measurement.rain_day
    params[:rainrate] = (measurement.rain_rate * 10).round(0) if measurement.rain_rate

    # Solar and UV (W/m² * 10, index * 10)
    params[:solarrad] = (measurement.light * 10).round(0) if measurement.light
    params[:uvi] = (measurement.uvi * 10).round(0) if measurement.uvi

    # Calculated values (C * 10)
    if measurement.dew_point
      params[:dew] = (measurement.dew_point * 10).round(0)
    end

    if measurement.feels_like
      # WeatherCloud uses heat index for feels like
      params[:heat] = (measurement.feels_like * 10).round(0)
    end

    wcloud_request = HTTParty.get(request_url, query: params)
    Rails.logger.info "WeatherCloud response: #{wcloud_request.body}"
  end

  def cwop(measurement)
    # TODO: Implement cwop
  end

  def openweathermap(measurement)
    # TODO: Implement openweathermap
  end

  def metoffice(measurement)
    # TODO: Implement metoffice
  end
end
