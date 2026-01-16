# frozen_string_literal: true

class Home::Forecast::Hourly::TileComponent < ViewComponent::Base
  attr_reader :hour, :icon_size, :night

  def initialize(hour:, night: false, icon_size: "1x")
    @hour = hour
    @night = night
    @icon_size = icon_size
  end
end
