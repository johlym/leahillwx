# frozen_string_literal: true

class RadarController < ApplicationController
  def index
    @lat = ENV.fetch("LOCATION_LAT").to_f
    @lon = ENV.fetch("LOCATION_LON").to_f
    @radar_sites = RadarSite.as_json
  end
end
