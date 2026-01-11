# frozen_string_literal: true

class Ui::CurrentWeather::WeatherTileComponent < ViewComponent::Base
  include ActionView::Helpers::NumberHelper

  attr_reader :tile_type, :heading, :measurement

  renders_one :primary_value
  renders_one :secondary_value

  def initialize(tile_type:, heading:, measurement: nil)
    @tile_type = tile_type
    @heading = heading
    @measurement = measurement
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

  def formatted_id
    number_with_delimiter(measurement.id)
  end
end
