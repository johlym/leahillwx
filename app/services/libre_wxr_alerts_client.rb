# frozen_string_literal: true

# Fetches active weather alerts near the station from LibreWXR (WMO CAP / NWS).
class LibreWxrAlertsClient
  DEFAULT_HOST = "https://api.librewxr.net"
  CACHE_TTL = 5.minutes
  REQUEST_TIMEOUT = 3

  def initialize(lat:, lon:, host: ENV.fetch("LIBREWXR_API_BASE", DEFAULT_HOST))
    @lat = lat
    @lon = lon
    @host = host.to_s.sub(%r{/+\z}, "").presence || DEFAULT_HOST
  end

  def fetch
    return [] if @lat.nil? || @lon.nil?

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      fetch_uncached
    end
  rescue StandardError => e
    Rails.logger.warn("[LibreWxrAlertsClient] #{e.class}: #{e.message}")
    []
  end

  private

  def cache_key
    "librewxr_alerts/#{@host}/#{@lat.to_f.round(3)},#{@lon.to_f.round(3)}"
  end

  def fetch_uncached
    url = "#{@host}/v2/alerts?lat=#{@lat}&lon=#{@lon}"
    payload = HttpClient.get_json(url, timeout: REQUEST_TIMEOUT)
    features = payload.is_a?(Hash) ? (payload["features"] || payload[:features]) : nil
    Array(features).filter_map { |feature| WeatherAlert.from_librewxr(feature) }
  end
end
