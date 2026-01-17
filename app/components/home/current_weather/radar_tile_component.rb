# frozen_string_literal: true

class Home::CurrentWeather::RadarTileComponent < ViewComponent::Base
  attr_reader :heading

  def initialize(heading:)
    @heading = heading
  end
end
