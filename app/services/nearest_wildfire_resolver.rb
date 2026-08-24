# frozen_string_literal: true

# Prefers live WA DNR incidents, enriches containment/URL from NIFC, then falls
# back to nearest NIFC fire in WA / Northwest.
#
# DNR "Current Fire Statistics" keeps rows until CONTROL_DT / FIRE_OUT_DT are
# set. Local-agency assist fires often never get those dates, so a nearby stale
# incident (e.g. a 3-acre fire from last month) would monopolize the card.
# Treat a DNR row as live only when NIFC still lists it, or it was discovered
# recently enough that NIFC may not have it yet.
class NearestWildfireResolver
  MATCH_DISTANCE_MI = 15.0
  RECENT_DNR_ONLY = 7.days

  def initialize(lat: ENV.fetch("LOCATION_LAT").to_f, lon: ENV.fetch("LOCATION_LON").to_f)
    @lat = lat
    @lon = lon
  end

  def call
    dnr_fires = WaDnrWildfireClient.new.active_fires
    nifc_fires = NifcWildfireClient.new.active_fires

    if (nearest_dnr = nearest(live_dnr_fires(dnr_fires, nifc_fires)))
      return enrich_from_nifc(nearest_dnr, nifc_fires)
    end

    wa = nifc_fires.select { |f| f[:state] == "WA" }
    nearest(wa) || nearest(nifc_fires)
  end

  private

  def live_dnr_fires(dnr_fires, nifc_fires)
    dnr_fires.select { |dnr| nifc_match_for(dnr, nifc_fires) || recently_discovered?(dnr) }
  end

  def recently_discovered?(fire)
    discovered_at = fire[:discovered_at]
    return false if discovered_at.blank?

    discovered_at >= RECENT_DNR_ONLY.ago
  end

  def nearest(fires)
    fires
      .map { |fire| fire.merge(distance_mi: GeoDistance.distance(@lat, @lon, fire[:lat], fire[:lon], unit: :mi)) }
      .min_by { |fire| fire[:distance_mi] }
  end

  def nifc_match_for(dnr_fire, nifc_fires)
    nifc_fires.find do |nifc|
      name_match = nifc[:name].to_s.downcase == dnr_fire[:name].to_s.downcase
      near = GeoDistance.distance(dnr_fire[:lat], dnr_fire[:lon], nifc[:lat], nifc[:lon], unit: :mi) <= MATCH_DISTANCE_MI
      name_match || near
    end
  end

  def enrich_from_nifc(dnr_fire, nifc_fires)
    match = nifc_match_for(dnr_fire, nifc_fires)
    return dnr_fire unless match

    dnr_fire.merge(
      percent_contained: match[:percent_contained],
      url: match[:url],
      acres: dnr_fire[:acres] || match[:acres],
      source: "wadnr+nifc"
    )
  end
end
