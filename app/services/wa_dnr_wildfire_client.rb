# frozen_string_literal: true

# Fetches live WA DNR wildfire statistics (state preferred source).
# Layer lacks percent contained — callers enrich from NIFC when possible.
#
# "Current DNR Fire Statistics" keeps incidents until FIRE_OUT_DT is set, which
# includes controlled / non-wildfire records. Restrict to uncontrolled wildfires.
# Callers still need NIFC corroboration or a recent DSCVR_DT — assist fires often
# never receive CONTROL_DT / FIRE_OUT_DT.
class WaDnrWildfireClient
  TIMEOUT_SECONDS = 20
  LAYER_URL = "https://gis.dnr.wa.gov/site3/rest/services/Public_Wildfire/WADNR_PUBLIC_WD_WildFire_Data/MapServer/1/query"

  # Live = not out, not controlled, wildfire class only (excludes DF/SF/VF, etc.).
  ACTIVE_WHERE = [
    "FIRE_OUT_DT IS NULL",
    "CONTROL_DT IS NULL",
    "FIREEVNT_CLASS_LABEL_NM = 'WF'"
  ].join(" AND ").freeze

  def active_fires
    data = HttpClient.get_json(
      LAYER_URL,
      query: {
        where: ACTIVE_WHERE,
        outFields: "INCIDENT_NM,ACRES_BURNED,LAT_COORD,LON_COORD,FIREEVENT_ID,INCIDENT_ID,OBJECTID,FIREEVNT_CLASS_LABEL_NM,DSCVR_DT",
        returnGeometry: true,
        outSR: 4326,
        f: "json"
      },
      timeout: TIMEOUT_SECONDS
    )

    if data["error"]
      Rails.logger.warn("WA DNR wildfire query error: #{data["error"].inspect}")
      return []
    end

    Array(data["features"]).filter_map { |feature| normalize(feature) }
  end


  private

  def normalize(feature)
    attrs = feature["attributes"] || {}
    geometry = feature["geometry"] || {}
    lat = attrs["LAT_COORD"] || geometry["y"]
    lon = attrs["LON_COORD"] || geometry["x"]
    return nil if lat.nil? || lon.nil?

    {
      name: attrs["INCIDENT_NM"].presence || "Unnamed fire",
      lat: lat.to_f,
      lon: lon.to_f,
      acres: attrs["ACRES_BURNED"]&.to_f,
      discovered_at: parse_arcgis_time(attrs["DSCVR_DT"]),
      external_id: attrs["FIREEVENT_ID"]&.to_s || attrs["OBJECTID"]&.to_s,
      source: "wadnr",
      class_label: attrs["FIREEVNT_CLASS_LABEL_NM"]
    }
  end

  # ArcGIS REST dates are epoch milliseconds.
  def parse_arcgis_time(value)
    return nil if value.blank?

    Time.zone.at(value.to_i / 1000.0)
  end
end
