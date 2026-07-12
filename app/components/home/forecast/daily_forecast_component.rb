# frozen_string_literal: true

class Home::Forecast::DailyForecastComponent < ViewComponent::Base
  attr_reader :days, :timestamp

  def initialize(days:, timestamp:)
    @days = days || []
    @timestamp = timestamp
  end

  def formatted_timestamp
    timestamp.in_time_zone("America/Los_Angeles").strftime("%b %d, %Y @ %I:%M %p")
  end
end
