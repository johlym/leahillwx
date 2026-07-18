# frozen_string_literal: true

# NOAA SWPC aurora products: current Kp, Kp forecast, and local OVATION probability.
class NoaaAuroraClient
  TIMEOUT_SECONDS = 15
  KP_URL = "https://services.swpc.noaa.gov/products/noaa-planetary-k-index.json"
  KP_FORECAST_URL = "https://services.swpc.noaa.gov/products/noaa-planetary-k-index-forecast.json"
  OVATION_URL = "https://services.swpc.noaa.gov/json/ovation_aurora_latest.json"

  def initialize(lat: ENV.fetch("LOCATION_LAT").to_f, lon: ENV.fetch("LOCATION_LON").to_f)
    @lat = lat
    @lon = lon
  end

  def outlook
    kp = current_kp
    forecast_max = kp_forecast_max_tonight
    ovation = local_ovation_pct

    {
      kp: kp,
      kp_forecast_max_tonight: forecast_max,
      local_ovation_pct: ovation,
      status_label: status_for(kp),
      odds_label: odds_for(forecast_max || kp, ovation)
    }
  end

  private

  def current_kp
    rows = HttpClient.get_json(KP_URL, timeout: TIMEOUT_SECONDS)
    # Header row then data rows: [time_tag, kp, a_running, station_count]
    data = rows.drop(1).last
    raise HttpClient::RequestError, "Empty Kp product" if data.blank?

    data[1].to_f
  end

  def kp_forecast_max_tonight
    rows = HttpClient.get_json(KP_FORECAST_URL, timeout: TIMEOUT_SECONDS)
    zone = ActiveSupport::TimeZone["America/Los_Angeles"]
    night_start = zone.now.beginning_of_day + 18.hours
    night_end = night_start + 12.hours

    values = rows.drop(1).filter_map do |row|
      time = Time.zone.parse(row[0].to_s) rescue nil
      next unless time
      next unless time.between?(night_start, night_end)

      row[1].to_f
    end

    values.max
  end

  def local_ovation_pct
    data = HttpClient.get_json(OVATION_URL, timeout: TIMEOUT_SECONDS)
    coords = data["coordinates"]
    return nil if coords.blank?

    # coordinates: [lon 0..360, lat, aurora%]
    target_lon = @lon < 0 ? @lon + 360.0 : @lon
    nearest = coords.min_by do |lon, lat, _|
      ((lon.to_f - target_lon).abs) + ((lat.to_f - @lat).abs)
    end
    nearest&.last&.to_f
  end

  def status_for(kp)
    case kp
    when 0...3 then "Quiet"
    when 3...5 then "Unsettled"
    when 5...7 then "Storm"
    else "Severe"
    end
  end

  def odds_for(kp, ovation)
    if ovation && ovation >= 5
      "Possible tonight (#{ovation.round}% local)"
    elsif kp >= 5
      "Elevated — watch northern skies"
    elsif kp >= 3
      "Low — unlikely from Auburn"
    else
      "Very low tonight"
    end
  end
end
