# frozen_string_literal: true

require "test_helper"

class Almanac::TextComponentTest < ViewComponent::TestCase
  setup do
    @almanac_entry = almanac_entries(:one)
    @date = @almanac_entry.date
  end

  def render_text(**overrides)
    args = { date: @date, almanac_entry: @almanac_entry, generation_time: 0.12 }.merge(overrides)
    render_inline(Almanac::TextComponent.new(**args)).to_s
  end

  test "renders the Astronomical Almanac header" do
    output = render_text

    assert_includes output, "Astronomical Almanac"
    assert_includes output, "=" * 80
  end

  test "renders the date in human-friendly long form" do
    output = render_text

    assert_includes output, "Date: #{@date.strftime("%A, %B %d, %Y")}"
  end

  test "renders the timezone from the almanac entry" do
    output = render_text

    assert_includes output, "Timezone: America/Los_Angeles"
  end

  test "renders SUN and MOON section headers" do
    output = render_text

    assert_includes output, "SUN"
    assert_includes output, "MOON"
  end

  def local_time(t)
    t.in_time_zone("America/Los_Angeles").strftime("%I:%M %p")
  end

  test "renders sunrise, solar noon, and sunset times" do
    output = render_text

    assert_match(/Sunrise:\s+#{Regexp.escape(local_time(@almanac_entry.sunrise_at))}/, output)
    assert_match(/Solar Noon:\s+#{Regexp.escape(local_time(@almanac_entry.solar_noon_at))}/, output)
    assert_match(/Sunset:\s+#{Regexp.escape(local_time(@almanac_entry.sunset_at))}/, output)
  end

  test "renders moonrise, transit, and moonset times" do
    output = render_text

    assert_match(/Moonrise:\s+#{Regexp.escape(local_time(@almanac_entry.moonrise_at))}/, output)
    assert_match(/Transit:\s+#{Regexp.escape(local_time(@almanac_entry.moon_transit_at))}/, output)
    assert_match(/Moonset:\s+#{Regexp.escape(local_time(@almanac_entry.moonset_at))}/, output)
  end

  test "renders moon phase capitalized and illumination percentage" do
    output = render_text

    assert_match(/Phase:\s+Waxing crescent/, output)
    assert_match(/Illumination:\s+25\.5%/, output)
  end

  test "renders formatted daylight duration" do
    output = render_text

    assert_includes output, "Daylight:"
    assert_includes output, @almanac_entry.formatted_daylight
  end

  test "renders daylight change line when delta is present" do
    output = render_text

    assert_includes output, "Change:"
    assert_includes output, @almanac_entry.formatted_daylight_delta
  end

  test "omits the daylight change line when delta is nil" do
    @almanac_entry.update!(daylight_delta_seconds: nil)

    output = render_text

    assert_no_match(/Change:/, output)
  end

  test "renders the ASTRONOMICAL EVENTS section when any event is present" do
    output = render_text

    assert_includes output, "ASTRONOMICAL EVENTS"
    assert_match(/Next New Moon:/, output)
    assert_match(/Next Full Moon:/, output)
    assert_match(/Next Equinox:/, output)
    assert_match(/Next Solstice:/, output)
  end

  test "omits the ASTRONOMICAL EVENTS section when no events are set" do
    @almanac_entry.update!(
      next_new_moon_at: nil,
      next_full_moon_at: nil,
      next_equinox_at: nil,
      next_solstice_at: nil
    )

    output = render_text

    assert_no_match(/ASTRONOMICAL EVENTS/, output)
  end

  test "renders only the events that are set" do
    @almanac_entry.update!(
      next_new_moon_at: 1.day.from_now,
      next_full_moon_at: nil,
      next_equinox_at: nil,
      next_solstice_at: nil
    )

    output = render_text

    assert_match(/Next New Moon:/, output)
    assert_no_match(/Next Full Moon:/, output)
    assert_no_match(/Next Equinox:/, output)
    assert_no_match(/Next Solstice:/, output)
  end

  test "renders generation time at the bottom" do
    output = render_text(generation_time: 0.42)

    assert_includes output, "Generation time: 0.42 seconds"
  end

  test "omits the dynamic-positions block when not provided" do
    output = render_text(dynamic_positions: nil)

    assert_no_match(/Current Position/, output)
    assert_no_match(/Note: Current positions calculated/, output)
  end

  test "renders sun dynamic position block when provided" do
    dynamic = {
      sun:  { azimuth: 128.4, altitude: 45.2, right_ascension: 60.1, declination: 22.3 },
      moon: { azimuth: 300.0, altitude: 10.5, right_ascension: 180.0, declination: -5.5 }
    }

    output = render_text(dynamic_positions: dynamic)

    assert_match(/SUN[\s\S]+Current Position/, output)
    assert_includes output, "Azimuth:          128.4°"
    assert_includes output, "Altitude:         45.2°"
    assert_includes output, "Right Ascension:  60.1°"
    assert_includes output, "Declination:      22.3°"
  end

  test "renders moon dynamic position block when provided" do
    dynamic = {
      moon: { azimuth: 300.0, altitude: 10.5, right_ascension: 180.0, declination: -5.5 }
    }

    output = render_text(dynamic_positions: dynamic)

    assert_match(/MOON[\s\S]+Current Position/, output)
    assert_includes output, "Azimuth:          300.0°"
    assert_includes output, "Declination:      -5.5°"
  end

  test "renders the approximate-algorithms note when dynamic_positions is set" do
    output = render_text(dynamic_positions: { sun: nil })

    assert_includes output, "Note: Current positions calculated using approximate algorithms."
  end
end
