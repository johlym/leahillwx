# frozen_string_literal: true

class Home::CurrentWeather::CelestialComponent < ViewComponent::Base
  attr_reader :almanac_today, :almanac_tomorrow

  def initialize(almanac_today:, almanac_tomorrow:)
    @almanac_today = almanac_today
    @almanac_tomorrow = almanac_tomorrow
  end

  def sun_events
    return {} unless almanac_today

    now = Time.current
    sunrise_today = almanac_today.sunrise_at
    sunset_today = almanac_today.sunset_at
    sunrise_tomorrow = almanac_tomorrow&.sunrise_at
    sunset_tomorrow = almanac_tomorrow&.sunset_at

    if sunrise_today && now < sunrise_today
      # Before sunrise - show today's sunrise and sunset
      { first: { label: "Sunrise", time: sunrise_today }, second: { label: "Sunset", time: sunset_today } }
    elsif sunset_today && now < sunset_today
      # After sunrise but before sunset - show today's sunset and tomorrow's sunrise
      { first: { label: "Sunset", time: sunset_today }, second: { label: "Sunrise", time: sunrise_tomorrow } }
    else
      # After sunset - show tomorrow's sunrise and sunset
      { first: { label: "Sunrise", time: sunrise_tomorrow }, second: { label: "Sunset", time: sunset_tomorrow } }
    end
  end

  def moon_events
    return {} unless almanac_today

    now = Time.current
    moonrise_today = almanac_today.moonrise_at
    moonset_today = almanac_today.moonset_at
    moonrise_tomorrow = almanac_tomorrow&.moonrise_at
    moonset_tomorrow = almanac_tomorrow&.moonset_at

    if moonrise_today && now < moonrise_today
      # Before moonrise - show today's moonrise and moonset
      { first: { label: "Moonrise", time: moonrise_today }, second: { label: "Moonset", time: moonset_today } }
    elsif moonset_today && now < moonset_today
      # After moonrise but before moonset - show today's moonset and tomorrow's moonrise
      { first: { label: "Moonset", time: moonset_today }, second: { label: "Moonrise", time: moonrise_tomorrow } }
    else
      # After moonset - show tomorrow's moonrise and moonset
      { first: { label: "Moonrise", time: moonrise_tomorrow }, second: { label: "Moonset", time: moonset_tomorrow } }
    end
  end

  def format_time(time)
    return "N/A" unless time

    time.in_time_zone(almanac_today&.timezone || "America/Los_Angeles").strftime("%-I:%M %p")
  end

  def upcoming_events
    return [] unless almanac_today

    events = []

    # Collect all possible events
    sun_data = sun_events
    moon_data = moon_events

    # Add sun events
    if sun_data[:first]
      events << {
        type: :sun,
        label: sun_data[:first][:label],
        time: sun_data[:first][:time],
        icon: "fa-sun"
      }
    end
    if sun_data[:second]
      events << {
        type: :sun,
        label: sun_data[:second][:label],
        time: sun_data[:second][:time],
        icon: "fa-sun"
      }
    end

    # Add moon events
    if moon_data[:first]
      events << {
        type: :moon,
        label: moon_data[:first][:label],
        time: moon_data[:first][:time],
        icon: "fa-moon"
      }
    end
    if moon_data[:second]
      events << {
        type: :moon,
        label: moon_data[:second][:label],
        time: moon_data[:second][:time],
        icon: "fa-moon"
      }
    end

    # Filter out nil times and sort by time
    events.reject { |e| e[:time].nil? }.sort_by { |e| e[:time] }
  end
end
