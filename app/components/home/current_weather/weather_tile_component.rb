# frozen_string_literal: true

class Home::CurrentWeather::WeatherTileComponent < ViewComponent::Base
  include ActionView::Helpers::NumberHelper

  attr_reader :tile_type, :heading, :measurement, :counter, :primary_target, :secondary_target

  renders_one :primary_value
  renders_one :secondary_value

  def initialize(tile_type:, heading: nil, measurement: nil, counter: 0, primary_target: nil, secondary_target: nil)
    @tile_type = tile_type
    @heading = heading
    @measurement = measurement
    @counter = number_with_delimiter(counter)
    @primary_target = primary_target
    @secondary_target = secondary_target
  end

  def heading?
    heading.present?
  end

  def temperature?
    tile_type == "current-temperature"
  end

  def formatted_temperature
    number_with_precision(measurement.temperature.to_fahrenheit, precision: 2, strip_insignificant_zeros: true)
  end

  def formatted_feels_like
    number_with_precision(measurement.feels_like.to_fahrenheit, precision: 2, strip_insignificant_zeros: true)
  end
end
