# frozen_string_literal: true

module ThirdPartyWeather
  class WeatherUnderground < Base
    URL = "https://weatherstation.wunderground.com/weatherstation/updateweatherstation.php"

    private

    def upload(measurement)
      Ambient.get(
        url: URL,
        station_id: ENV.fetch("WU_STATION_ID"),
        password: ENV.fetch("WU_STATION_KEY"),
        measurement: measurement,
        include_weather_clouds: true,
        service_name: service_name
      )
    end

    def service_name
      "weatherunderground"
    end

    def required_env
      %w[WU_STATION_ID WU_STATION_KEY]
    end
  end
end
