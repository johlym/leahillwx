# frozen_string_literal: true

class Ui::EarthquakeTableComponent < ViewComponent::Base
  def initialize(earthquakes:)
    @earthquakes = earthquakes
  end
end
