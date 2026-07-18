# frozen_string_literal: true

class Home::CurrentWeather::SoilComponent < ViewComponent::Base
  def initialize(readings: [])
    @readings = Array(readings)
  end

  def readings?
    @readings.any?
  end

  attr_reader :readings
end
