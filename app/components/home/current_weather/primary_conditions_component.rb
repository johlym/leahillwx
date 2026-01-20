# frozen_string_literal: true

class Home::CurrentWeather::PrimaryConditionsComponent < ViewComponent::Base
  def initialize(current:, almanac:)
    @current = current
    @almanac = almanac
  end

  def season
  end
end
