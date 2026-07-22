# frozen_string_literal: true

# Normalized weather alert for the homepage bar and /alerts (LibreWXR and/or OpenWeather).
class WeatherAlert
  attr_reader :event, :title, :description, :starts_at, :ends_at, :source,
              :severity, :regions, :uri, :sender_name, :tags

  def initialize(
    event:,
    description: nil,
    starts_at: nil,
    ends_at: nil,
    source: nil,
    title: nil,
    severity: nil,
    regions: nil,
    uri: nil,
    sender_name: nil,
    tags: nil
  )
    @event = event
    @title = title.presence || event
    @description = description
    @starts_at = starts_at
    @ends_at = ends_at
    @source = source
    @severity = severity
    @regions = Array(regions).flat_map { |region| region.to_s.split(/\s*;\s*/) }.map(&:presence).compact
    @uri = uri
    @sender_name = sender_name
    @tags = Array(tags)
  end

  def self.from_librewxr(feature)
    props = feature.is_a?(Hash) ? feature["properties"] || feature[:properties] || feature : {}
    props = props.deep_symbolize_keys
    raw_title = props[:title].presence || props[:event].presence || "Weather alert"
    new(
      event: shorten_librewxr_title(raw_title),
      title: raw_title,
      description: props[:description],
      starts_at: unix_time(props[:time]),
      ends_at: unix_time(props[:expires]),
      source: "librewxr",
      severity: props[:severity],
      regions: props[:regions],
      uri: props[:uri]
    )
  end

  def self.from_open_weather(alert)
    new(
      event: alert.event.presence || "Weather alert",
      title: alert.event.presence || "Weather alert",
      description: alert.description,
      starts_at: alert.start_time,
      ends_at: alert.end_time,
      source: "openweather",
      sender_name: alert.try(:sender_name),
      tags: alert.try(:tags)
    )
  end

  def self.active_nearby(lat:, lon:, forecast_alerts: [])
    librewxr = LibreWxrAlertsClient.new(lat: lat, lon: lon).fetch
    openweather = Array(forecast_alerts).filter_map do |alert|
      next unless alert.respond_to?(:active?) ? alert.active? : true

      from_open_weather(alert)
    end
    (librewxr + openweather).select(&:active?).uniq(&:event)
  end

  # Back-compat alias used by RootController.
  def self.for_homepage(...)
    active_nearby(...)
  end

  def active?
    now = Time.current
    return false if ends_at && ends_at < now
    return false if starts_at && starts_at > now

    true
  end

  # Compatibility with the alerts bar component.
  def end_time
    ends_at
  end

  def source_label
    case source
    when "librewxr" then "NWS / LibreWXR"
    when "openweather" then "OpenWeather"
    else source.to_s.presence || "Weather service"
    end
  end

  def self.unix_time(value)
    return nil if value.blank?

    Time.zone.at(value.to_i)
  end
  private_class_method :unix_time

  # LibreWXR titles look like:
  # "Heat Advisory issued July 22 at 3:12PM PDT until ... by NWS Seattle WA"
  def self.shorten_librewxr_title(title)
    shortened = title.to_s.sub(/\s+issued\b.*/i, "").strip
    shortened.presence || title.to_s.presence || "Weather alert"
  end
  private_class_method :shorten_librewxr_title
end
