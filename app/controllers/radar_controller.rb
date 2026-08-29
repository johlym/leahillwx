# frozen_string_literal: true

class RadarController < ApplicationController
  DEFAULT_LIBREWXR_HOST = "https://api.librewxr.net"

  def index
    @lat = ENV.fetch("LOCATION_LAT").to_f
    @lon = ENV.fetch("LOCATION_LON").to_f
    @radar_sites = RadarSite.as_json
    @librewxr_host = ENV.fetch("LIBREWXR_API_BASE", DEFAULT_LIBREWXR_HOST)
    # Free CARTO basemap key; passed to Leaflet as ?key= (client-side by design).
    @carto_api_key = ENV.fetch("CARTO_API_KEY", "")
  end
end
