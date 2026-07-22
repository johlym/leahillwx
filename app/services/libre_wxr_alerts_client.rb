# frozen_string_literal: true

# Fetches active weather alerts near the station from LibreWXR (WMO CAP / NWS).
class LibreWxrAlertsClient
  DEFAULT_HOST = "https://api.librewxr.net"
  CACHE_TTL = 5.minutes
  REQUEST_TIMEOUT = 3

  def initialize(lat:, lon:, host: ENV.fetch("LIBREWXR_API_BASE", DEFAULT_HOST))
    @lat = lat
    @lon = lon
    @host = self.class.normalize_host(host)
  end

  def fetch
    return [] unless coordinates?

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      fetch_uncached
    end
  rescue StandardError => e
    Rails.logger.warn("[LibreWxrAlertsClient] #{e.class}: #{e.message}")
    []
  end

  # Parse station coordinates from env. Blank / non-numeric values → [nil, nil]
  # so we never query LibreWXR for (0.0, 0.0) from "".to_f.
  def self.coordinates_from_env
    lat_raw = ENV["LOCATION_LAT"].presence
    lon_raw = ENV["LOCATION_LON"].presence
    return [ nil, nil ] if lat_raw.blank? || lon_raw.blank?

    lat = Float(lat_raw, exception: false)
    lon = Float(lon_raw, exception: false)
    return [ nil, nil ] if lat.nil? || lon.nil?

    [ lat, lon ]
  end

  # Match radar JS normalizeLibreWxrHost: accept origin or full metadata URL.
  def self.normalize_host(host)
    trimmed = host.to_s.strip.sub(%r{/+\z}, "")
    suffix = "/public/weather-maps.json"
    if trimmed.end_with?(suffix)
      trimmed = trimmed.delete_suffix(suffix)
    end
    trimmed.presence || DEFAULT_HOST
  end

  private

  def coordinates?
    @lat.is_a?(Numeric) && @lon.is_a?(Numeric)
  end

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
