class GeoDistanceService
  EARTH_RADIUS_KM = 6371.0
  EARTH_RADIUS_MI = 3958.8

  def self.distance(lat1, lon1, lat2, lon2, unit: :km)
    rad = Math::PI / 180

    dlat = (lat2 - lat1) * rad
    dlon = (lon2 - lon1) * rad

    a =
      Math.sin(dlat / 2)**2 +
      Math.cos(lat1 * rad) *
      Math.cos(lat2 * rad) *
      Math.sin(dlon / 2)**2

    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

    radius = unit == :mi ? EARTH_RADIUS_MI : EARTH_RADIUS_KM
    radius * c
  end
end
