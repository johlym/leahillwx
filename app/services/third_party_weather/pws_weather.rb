# frozen_string_literal: true

module ThirdPartyWeather
  # PWSWeather uses the Ambient / Weather Underground protocol (weewx StdPWSWeather).
  class PwsWeather < Base
    URL = "https://www.pwsweather.com/pwsupdate/pwsupdate.php"

    private

    def upload(measurement)
      Ambient.get(
        url: URL,
        station_id: ENV.fetch("PWS_STATION_ID"),
        password: ENV.fetch("PWS_STATION_KEY"),
        measurement: measurement,
        include_weather_clouds: false,
        service_name: service_name
      )
    end

    def service_name
      "pwsweather"
    end

    def required_env
      %w[PWS_STATION_ID PWS_STATION_KEY]
    end
  end
end
