# frozen_string_literal: true

class Home::EarthquakeTableComponent < ViewComponent::Base
  def initialize(earthquakes:)
    @earthquakes = earthquakes
  end
end
