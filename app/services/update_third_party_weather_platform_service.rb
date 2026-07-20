# frozen_string_literal: true

require "digest"
require "socket"

class UpdateThirdPartyWeatherPlatformService
  SUPPORTED_SERVICES = [
    "weatherunderground",
    "pwsweather",
    "awekas",
    "weathercloud",
    "cwop"
  ].freeze

  SOFTWARE_TYPE = "lhwx"
  HTTP_TIMEOUT = 10
  CWOP_HOST = "cwop.aprs.net"
  CWOP_PORTS = [ 14580, 23 ].freeze
  CWOP_PASSCODE = "-1"
  CWOP_MIN_INTERVAL = 5.minutes
  CWOP_CACHE_KEY = "third_party_upload:cwop:last_sent_at"

  def initialize(weather_measurement, service, socket_factory: TCPSocket)
    @weather_measurement = weather_measurement
    @service = service
    @socket_factory = socket_factory

    raise ArgumentError, "Unsupported service: #{@service}" unless SUPPORTED_SERVICES.include?(@service)
  end

  def perform
    Rails.logger.info "Updating third party weather platform: #{@service}"

    send("update_#{@service}", @weather_measurement)

    Rails.logger.info "Update complete for: #{@service}"
  end

  def update_weatherunderground(measurement)
    date_utc = measurement.reading_date_time.utc.strftime("%Y-%m-%d+%H:%M:%S")

    request_url = "https://weatherstation.wunderground.com/weatherstation/updateweatherstation.php"
    request_params = {
      ID: ENV["WU_STATION_ID"],
      PASSWORD: ENV["WU_STATION_KEY"],
      dateutc: date_utc,
      winddir: measurement.wind_dir,
      windspeedmph: measurement.wind_speed_mph.round(2),
      windgustmph: measurement.gust_speed_mph.round(2),
      tempf: measurement.temperature.to_fahrenheit.round(2),
      rainin: measurement.rain_rate_in.round(4),
      dailyrainin: measurement.rain_day_in.round(4),
      baromin: measurement.barometer_rel_inhg.round(3),
      dewptf: measurement.dew_point.to_fahrenheit.round(2),
      humidity: measurement.humidity,
      weather: "",
      clouds: "",
      softwaretype: SOFTWARE_TYPE,
      action: "updateraw"
    }

    response = HTTParty.post(request_url, query: request_params, timeout: HTTP_TIMEOUT)
    Rails.logger.info "Weather Underground response: #{response.body}"
  end

  def update_pwsweather(measurement)
    # PWSWeather uses the Weather Underground protocol
    # Documentation: http://wiki.wunderground.com/index.php/PWS_-_Upload_Protocol

    date_utc = measurement.reading_date_time.utc.strftime("%Y-%m-%d+%H:%M:%S")

    request_url = "https://www.pwsweather.com/pwsupdate/pwsupdate.php"
    request_params = {
      ID: ENV["PWS_STATION_ID"],
      PASSWORD: ENV["PWS_STATION_KEY"],
      dateutc: date_utc,
      winddir: measurement.wind_dir,
      windspeedmph: measurement.wind_speed_mph.round(2),
      windgustmph: measurement.gust_speed_mph.round(2),
      tempf: measurement.temperature.to_fahrenheit.round(2),
      rainin: measurement.rain_rate_in.round(4),
      dailyrainin: measurement.rain_day_in.round(4),
      baromin: measurement.barometer_rel_inhg.round(3),
      dewptf: measurement.dew_point.to_fahrenheit.round(2),
      humidity: measurement.humidity,
      softwaretype: SOFTWARE_TYPE,
      action: "updateraw"
    }

    response = HTTParty.post(request_url, query: request_params, timeout: HTTP_TIMEOUT)
    Rails.logger.info "PWSWeather response: #{response.body}"
  end

  def update_awekas(measurement)
    # AWEKAS API uses semicolon-separated values
    # Documentation: Based on weewx implementation at
    # https://github.com/weewx/weewx/blob/master/src/weewx/restx.py#L1608

    password_hash = Digest::MD5.hexdigest(ENV.fetch("AWEKAS_PASSWORD"))

    time_utc = measurement.reading_date_time.utc
    date_str = time_utc.strftime("%d.%m.%Y")
    time_str = time_utc.strftime("%H:%M")

    temp_c = measurement.temperature
    humidity = measurement.humidity
    barometer_hpa = measurement.barometer_rel
    daily_rain_mm = (measurement.rain_day * 10).round(1) # mm * 10 as per AWEKAS spec
    wind_speed_kmh = (measurement.wind_speed * 3.6).round(1) # m/s to km/h
    wind_dir = measurement.wind_dir
    wind_gust_kmh = (measurement.gust_speed * 3.6).round(1) # m/s to km/h
    solar_radiation = measurement.light
    uv_index = measurement.uvi
    rain_rate_mmh = (measurement.rain_rate * 10).round(1) # mm/h * 10 as per AWEKAS spec

    values = [
      ENV["AWEKAS_USERNAME"],
      password_hash,
      date_str,
      time_str,
      temp_c,
      humidity,
      barometer_hpa,
      daily_rain_mm,
      wind_speed_kmh,
      wind_dir,
      "", # weather condition
      "", # warning text
      "", # snow height
      "en", # language
      "", # tendency
      wind_gust_kmh,
      solar_radiation,
      uv_index,
      "", # brightness in lux
      "", # sunshine hours
      "", # soil temperature
      rain_rate_mmh,
      SOFTWARE_TYPE,
      ENV["LOCATION_LON"],
      ENV["LOCATION_LAT"]
    ]

    val_string = values.join(";")

    request_url = "https://data.awekas.at/get.php"
    response = HTTParty.get(request_url, query: { val: val_string }, timeout: HTTP_TIMEOUT)
    Rails.logger.info "AWEKAS response: #{response.body}"
  end

  def update_weathercloud(measurement)
    # WeatherCloud API v01
    # Documentation: Based on weewx-wcloud implementation at
    # https://github.com/matthewwall/weewx-wcloud
    # Note: WeatherCloud expects values in metric with specific multipliers

    request_url = "https://api.weathercloud.net/v01/set"
    params = {
      wid: ENV["WEATHERCLOUD_DEVICE_ID"],
      key: ENV["WEATHERCLOUD_DEVICE_KEY"]
    }

    params[:temp] = (measurement.temperature * 10).round(0) if measurement.temperature
    params[:hum] = measurement.humidity.round(0) if measurement.humidity
    params[:tempin] = (measurement.temperature * 10).round(0) if measurement.temperature

    params[:wspd] = (measurement.wind_speed * 10).round(0) if measurement.wind_speed
    params[:wdir] = measurement.wind_dir.round(0) if measurement.wind_dir
    params[:wspdhi] = (measurement.gust_speed * 10).round(0) if measurement.gust_speed

    params[:bar] = (measurement.barometer_rel * 10).round(0) if measurement.barometer_rel

    params[:rain] = (measurement.rain_day * 10).round(0) if measurement.rain_day
    params[:rainrate] = (measurement.rain_rate * 10).round(0) if measurement.rain_rate

    params[:solarrad] = (measurement.light * 10).round(0) if measurement.light
    params[:uvi] = (measurement.uvi * 10).round(0) if measurement.uvi

    if measurement.dew_point
      params[:dew] = (measurement.dew_point * 10).round(0)
    end

    if measurement.feels_like
      params[:heat] = (measurement.feels_like * 10).round(0)
    end

    response = HTTParty.get(request_url, query: params, timeout: HTTP_TIMEOUT)
    Rails.logger.info "WeatherCloud response: #{response.body}"
  end

  def update_cwop(measurement)
    return unless cwop_due?

    callsign = ENV.fetch("CWOP_CALLSIGN")
    packet = build_cwop_packet(measurement, callsign)
    send_cwop_packet(callsign, packet)
    Rails.cache.write(CWOP_CACHE_KEY, Time.current.to_f, expires_in: CWOP_MIN_INTERVAL * 2)
  end

  private

  def cwop_due?
    last_sent_at = Rails.cache.read(CWOP_CACHE_KEY)
    return true if last_sent_at.blank?

    Time.current.to_f - last_sent_at.to_f >= CWOP_MIN_INTERVAL.to_f
  end

  def build_cwop_packet(measurement, callsign)
    lat = ENV.fetch("LOCATION_LAT").to_f
    lon = ENV.fetch("LOCATION_LON").to_f
    time_utc = measurement.reading_date_time.utc

    timestamp = time_utc.strftime("%d%H%Mz")
    position = "#{format_aprs_latitude(lat)}/#{format_aprs_longitude(lon)}"

    wind_dir = format("%03d", measurement.wind_dir.round.clamp(0, 360) % 360)
    wind_speed = format("%03d", measurement.wind_speed_mph.round.clamp(0, 999))
    gust = format("%03d", measurement.gust_speed_mph.round.clamp(0, 999))
    temp_f = format("%03d", measurement.temperature.to_fahrenheit.round.clamp(-99, 999))
    rain_hour = format("%03d", (rain_last_hour_inches(measurement) * 100).round.clamp(0, 999))
    rain_24h = format("%03d", (rain_last_24h_inches(measurement) * 100).round.clamp(0, 999))
    rain_day = format("%03d", (measurement.rain_day_in * 100).round.clamp(0, 999))
    humidity = format("%02d", measurement.humidity == 100 ? 0 : measurement.humidity.clamp(0, 99))
    pressure = format("%05d", (measurement.barometer_abs * 10).round.clamp(0, 99_999))

    weather = "#{wind_dir}/#{wind_speed}g#{gust}t#{temp_f}r#{rain_hour}p#{rain_24h}P#{rain_day}h#{humidity}b#{pressure}"

    "#{callsign}>APRS,TCPIP*:@#{timestamp}#{position}_#{weather}"
  end

  def format_aprs_latitude(lat)
    hemisphere = lat >= 0 ? "N" : "S"
    abs_lat = lat.abs
    degrees = abs_lat.floor
    minutes = (abs_lat - degrees) * 60.0
    format("%02d%05.2f%s", degrees, minutes, hemisphere)
  end

  def format_aprs_longitude(lon)
    hemisphere = lon >= 0 ? "E" : "W"
    abs_lon = lon.abs
    degrees = abs_lon.floor
    minutes = (abs_lon - degrees) * 60.0
    format("%03d%05.2f%s", degrees, minutes, hemisphere)
  end

  def rain_last_hour_inches(measurement)
    window_start = measurement.reading_date_time - 1.hour
    earlier = WeatherMeasurement
      .where(reading_date_time: window_start..measurement.reading_date_time)
      .order(:reading_date_time)
      .first

    return measurement.rain_rate_in if earlier.nil? || earlier.id == measurement.id

    delta_mm = measurement.rain_day - earlier.rain_day
    delta_mm = 0.0 if delta_mm.negative? # day counter reset
    delta_mm / 25.4
  end

  def rain_last_24h_inches(measurement)
    window_start = measurement.reading_date_time - 24.hours
    readings = WeatherMeasurement
      .where(reading_date_time: window_start..measurement.reading_date_time)
      .order(:reading_date_time)
      .pluck(:reading_date_time, :rain_day)

    return measurement.rain_day_in if readings.size < 2

    total_mm = 0.0
    readings.each_cons(2) do |(_t0, rain0), (_t1, rain1)|
      delta = rain1 - rain0
      total_mm += delta if delta.positive?
    end
    total_mm / 25.4
  end

  def send_cwop_packet(callsign, packet)
    last_error = nil

    CWOP_PORTS.each do |port|
      socket = nil
      begin
        socket = @socket_factory.open(CWOP_HOST, port)
        socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1) if socket.respond_to?(:setsockopt)
        read_line(socket) # server banner
        socket.write("user #{callsign} pass #{CWOP_PASSCODE} vers #{SOFTWARE_TYPE} 1.0\r\n")
        read_line(socket) # login ack
        socket.write("#{packet}\r\n")
        Rails.logger.info "CWOP packet sent via #{CWOP_HOST}:#{port}: #{packet}"
        return
      rescue StandardError => e
        last_error = e
        Rails.logger.warn "CWOP send via #{CWOP_HOST}:#{port} failed: #{e.message}"
      ensure
        socket&.close
      end
    end

    raise last_error if last_error
  end

  def read_line(socket)
    return unless socket.respond_to?(:gets)

    socket.gets
  end
end
