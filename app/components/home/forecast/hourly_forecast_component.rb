# frozen_string_literal: true

class Home::Forecast::HourlyForecastComponent < ViewComponent::Base
  attr_reader :hours, :timestamp

  def initialize(hours:, timestamp:)
    @hours = hours || []
    @timestamp = timestamp
  end

  def formatted_timestamp
    timestamp.in_time_zone("America/Los_Angeles").strftime("%B %-d, %Y @ %H:%S")
  end
end
