# frozen_string_literal: true

class Ui::ForecastWeather::SidebarTileComponent < ViewComponent::Base
  attr_reader :heading

  def initialize(heading: nil)
    @heading = heading
  end
end
