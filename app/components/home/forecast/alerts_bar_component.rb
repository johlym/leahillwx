# frozen_string_literal: true

class Home::Forecast::AlertsBarComponent < ViewComponent::Base
  def initialize(alerts:)
    @alerts = Array(alerts).select(&:active?)
  end

  def render?
    @alerts.any?
  end

  def primary_alert
    @alerts.first
  end

  def extra_count
    [ @alerts.length - 1, 0 ].max
  end

  def ends_label(alert)
    return nil unless alert.end_time

    alert.end_time.in_time_zone("America/Los_Angeles").strftime("%-I:%M %p %Z")
  end
end
