# frozen_string_literal: true

class Home::Forecast::AlertsBarComponent < ViewComponent::Base
  def initialize(alerts:)
    @alerts = Array(alerts).select { |alert| alert.respond_to?(:active?) ? alert.active? : true }
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
    ends_at = alert.respond_to?(:end_time) ? alert.end_time : alert.try(:ends_at)
    return nil unless ends_at

    ends_at.in_time_zone("America/Los_Angeles").strftime("%-I:%M %p %Z")
  end

  def event_label(alert)
    alert.try(:event).presence || alert.try(:title).presence || "Weather alert"
  end
end
