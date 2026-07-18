# frozen_string_literal: true

class Home::CurrentWeather::SoilComponent < ViewComponent::Base
  BATTERY_ICONS = {
    5 => "fa-battery-full",
    4 => "fa-battery-half",
    3 => "fa-battery-low",
    2 => "fa-battery-exclamation",
    1 => "fa-battery-exclamation"
  }.freeze

  BATTERY_OK_STYLE = "--fa-primary-color: rgb(120, 230, 99); --fa-secondary-color: rgb(255, 255, 255); --fa-secondary-opacity: 1;"
  BATTERY_CRITICAL_STYLE = "--fa-primary-color: rgb(230, 99, 99); --fa-secondary-color: rgb(230, 99, 99); --fa-secondary-opacity: 1;"

  def initialize(readings: [])
    @readings = Array(readings)
  end

  def readings?
    @readings.any?
  end

  def battery_icon_name(level)
    BATTERY_ICONS[level.to_i]
  end

  def battery_critical?(level)
    level.to_i <= 2
  end

  def battery_style(level)
    battery_critical?(level) ? BATTERY_CRITICAL_STYLE : BATTERY_OK_STYLE
  end

  attr_reader :readings
end
