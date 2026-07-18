# frozen_string_literal: true

# NIFC WFIGS current incident locations — contains PercentContained and links.
class NifcWildfireClient
  TIMEOUT_SECONDS = 20
  LAYER_URL = "https://services3.arcgis.com/T4QMspbfLg3qTGWY/arcgis/rest/services/WFIGS_Incident_Locations_Current/FeatureServer/0/query"

  # WFIGS encodes states as US-WA / US-OR / US-ID.
  NORTHWEST_STATE_CODES = %w[WA OR ID].freeze

  def active_fires(states: NORTHWEST_STATE_CODES)
    state_clause = states.map { |s|
      "POOState = 'US-#{s}' OR POOState = '#{s}'"
    }.join(" OR ")
    where = "IncidentTypeCategory = 'WF' AND (#{state_clause})"

    data = HttpClient.get_json(
      LAYER_URL,
      query: {
        where: where,
        outFields: [
          "IncidentName",
          "PercentContained",
          "IncidentSize",
          "UniqueFireIdentifier",
          "IrwinID",
          "POOState"
        ].join(","),
        returnGeometry: true,
        outSR: 4326,
        f: "json"
      },
      timeout: TIMEOUT_SECONDS
    )

    if data["error"]
      Rails.logger.warn("NIFC wildfire query error: #{data["error"].inspect}")
      return []
    end

    Array(data["features"]).filter_map { |feature| normalize(feature) }
  end


  private

  def normalize(feature)
    attrs = feature["attributes"] || {}
    geometry = feature["geometry"] || {}
    lat = geometry["y"]
    lon = geometry["x"]
    return nil if lat.nil? || lon.nil?

    irwin = attrs["IrwinID"].presence || attrs["UniqueFireIdentifier"].presence
    state = attrs["POOState"].to_s.delete_prefix("US-")
    {
      name: attrs["IncidentName"].presence || "Unnamed fire",
      lat: lat.to_f,
      lon: lon.to_f,
      acres: attrs["IncidentSize"]&.to_f,
      percent_contained: attrs["PercentContained"]&.to_f,
      external_id: irwin,
      url: inciweb_url(attrs),
      source: "nifc",
      state: state
    }
  end

  def inciweb_url(attrs)
    # InciWeb search by incident name; IRWIN deep links are unstable across seasons.
    name = attrs["IncidentName"].to_s
    return nil if name.blank?

    "https://inciweb.wildfire.gov/incident-information/search?query=#{CGI.escape(name)}"
  end
end
