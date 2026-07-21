# frozen_string_literal: true

# Local NEXRAD sites available as single-radar RIDGE overlays on /radar.
# Coordinates from NCEI HOMR nexrad-stations. IEM TMS sector codes omit the
# leading "K" (e.g. KATX → ATX).
class RadarSite
  Site = Data.define(:id, :sector, :name, :lat, :lon)

  SITES = [
    Site.new(
      id: "KATX",
      sector: "ATX",
      name: "Camano Island",
      lat: 48.194611,
      lon: -122.49569
    ),
    Site.new(
      id: "KRTX",
      sector: "RTX",
      name: "Portland",
      lat: 45.715039,
      lon: -122.965
    ),
    Site.new(
      id: "KLGX",
      sector: "LGX",
      name: "Langley Hill",
      lat: 47.116944,
      lon: -124.10666
    )
  ].freeze

  def self.all
    SITES
  end

  def self.find(id)
    SITES.find { |site| site.id == id.to_s.upcase }
  end

  def self.as_json(*)
    SITES.map do |site|
      {
        id: site.id,
        sector: site.sector,
        name: site.name,
        lat: site.lat,
        lon: site.lon
      }
    end
  end
end
