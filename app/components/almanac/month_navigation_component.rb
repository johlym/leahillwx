# frozen_string_literal: true

class Almanac::MonthNavigationComponent < ViewComponent::Base
  def initialize(current_year:, current_month:, location:)
    @current_year = current_year
    @current_month = current_month
    @location = location
  end

  private

  attr_reader :current_year, :current_month, :location

  def current_date
    @current_date ||= Date.new(current_year, current_month, 1)
  end

  def prev_month
    current_date - 1.month
  end

  def next_month
    current_date + 1.month
  end

  def month_name
    Date::MONTHNAMES[current_month]
  end

  def location_heading
    # Calculate compass heading from lat/lon
    # For now, return formatted location string
    lat = location[:lat]
    lon = location[:lon]
    lat_dir = lat >= 0 ? "N" : "S"
    lon_dir = lon >= 0 ? "E" : "W"
    "#{lat.abs.round(4)}°#{lat_dir}, #{lon.abs.round(4)}°#{lon_dir}"
  end
end
