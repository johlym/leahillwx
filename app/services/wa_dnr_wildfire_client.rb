# frozen_string_literal: true

# Fetches current WA DNR fire statistics (state preferred source).
# Layer lacks percent contained — callers enrich from NIFC when possible.
class WaDnrWildfireClient
  TIMEOUT_SECONDS = 20
  LAYER_URL = "https://gis.dnr.wa.gov/site3/rest/services/Public_Wildfire/WADNR_PUBLIC_WD_WildFire_Data/MapServer/1/query"

  def active_fires
    data = HttpClient.get_json(
      LAYER_URL,
      query: {
        where: "FIRE_OUT_DT IS NULL",
        outFields: "INCIDENT_NM,ACRES_BURNED,LAT_COORD,LON_COORD,FIREEVENT_ID,INCIDENT_ID,OBJECTID,FIREEVNT_CLASS_LABEL_NM",
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

    # Prefer wildfire-class incidents; keep others if that's all we have.
    {
      name: attrs["INCIDENT_NM"].presence || "Unnamed fire",
      lat: lat.to_f,
      lon: lon.to_f,
      acres: attrs["ACRES_BURNED"]&.to_f,
      external_id: attrs["FIREEVENT_ID"]&.to_s || attrs["OBJECTID"]&.to_s,
      source: "wadnr",
      class_label: attrs["FIREEVNT_CLASS_LABEL_NM"]
    }
  end
end
