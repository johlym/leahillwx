# frozen_string_literal: true

class DownloadOpenWeatherAqiJob
  include Sidekiq::Job

  def perform(*_args)
    payload = OpenWeatherClient.new.retrieve_aqi
    entry = payload.fetch("list").fetch(0)
    components = entry.fetch("components")

    Aqi.upsert_reading!(
      observed_at: Time.at(entry.fetch("dt")).utc,
      pm2_5: components["pm2_5"],
      source: "openweather",
      co: components["co"],
      no: components["no"],
      no2: components["no2"],
      o3: components["o3"],
      so2: components["so2"],
      pm10: components["pm10"],
      nh3: components["nh3"]
    )
  rescue OpenWeatherClient::RequestError, KeyError => e
    Rails.logger.warn("OpenWeather AQI download failed: #{e.message}")
  end
end
