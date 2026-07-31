# == Schema Information
#
# Table name: weather_measurements
#
#  id                :bigint           not null, primary key
#  barometer_abs     :float            not null
#  barometer_rel     :float            not null
#  gust_speed        :float            not null
#  humidity          :integer          not null
#  light             :float            not null
#  rain_day          :float            default(0.0), not null
#  rain_rate         :float            not null
#  reading_date_time :datetime         not null
#  soil              :jsonb            not null
#  temp_probes       :jsonb            not null
#  temperature       :float            not null
#  uv                :integer          not null
#  uvi               :float            not null
#  wind_dir          :integer          not null
#  wind_speed        :float            not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_weather_measurements_on_barometer_rel      (barometer_rel)
#  index_weather_measurements_on_gust_speed         (gust_speed)
#  index_weather_measurements_on_humidity           (humidity)
#  index_weather_measurements_on_light              (light)
#  index_weather_measurements_on_rain_day           (rain_day)
#  index_weather_measurements_on_rain_rate          (rain_rate)
#  index_weather_measurements_on_reading_date_time  (reading_date_time) UNIQUE
#  index_weather_measurements_on_temperature        (temperature)
#  index_weather_measurements_on_wind_speed         (wind_speed)
#
require "test_helper"

class WeatherMeasurementTest < ActiveSupport::TestCase
  def valid_attrs(overrides = {})
    {
      reading_date_time: Time.current,
      barometer_abs: 1013.2,
      barometer_rel: 1015.0,
      gust_speed: 2.5,
      light: 1200.0,
      humidity: 65,
      temperature: 18.5,
      rain_day: 0.0,
      rain_rate: 0.0,
      uv: 3,
      uvi: 3.0,
      wind_dir: 180,
      wind_speed: 1.2
    }.merge(overrides)
  end

  test "converts barometer from hPa to inHg" do
    measurement = WeatherMeasurement.new(valid_attrs(barometer_abs: 1013.25, barometer_rel: 1015.0))

    assert_in_delta 1013.25 / 33.8638866667, measurement.barometer_abs_inhg, 0.000001
    assert_in_delta 1015.0 / 33.8638866667, measurement.barometer_rel_inhg, 0.000001
    assert_in_delta measurement.barometer_abs_inhg, measurement.barometer_abs_mmhg, 0.000001
  end

  test "accepts empty soil by default" do
    measurement = WeatherMeasurement.new(valid_attrs)
    assert measurement.valid?
    assert_equal [], measurement.soil
  end

  test "accepts valid soil channels" do
    measurement = WeatherMeasurement.new(valid_attrs(
      soil: [
        { "channel" => 1, "moisture" => 78.0, "battery" => 1.6 },
        { "channel" => 2, "moisture" => 55.5, "battery" => 1.5 }
      ]
    ))

    assert measurement.valid?
    assert_equal 2, measurement.soil.size
    assert_equal 1, measurement.soil.first["channel"]
    assert_equal 1.6, measurement.soil.first["battery"]
  end

  test "rejects more than 8 soil channels" do
    soil = (1..9).map { |channel| { "channel" => channel, "moisture" => 50.0, "battery" => 1.5 } }
    measurement = WeatherMeasurement.new(valid_attrs(soil: soil))

    assert_not measurement.valid?
    assert_includes measurement.errors[:soil], "cannot have more than 8 entries"
  end

  test "rejects duplicate soil channels" do
    measurement = WeatherMeasurement.new(valid_attrs(
      soil: [
        { "channel" => 1, "moisture" => 78.0, "battery" => 1.6 },
        { "channel" => 1, "moisture" => 55.5, "battery" => 1.5 }
      ]
    ))

    assert_not measurement.valid?
    assert_includes measurement.errors[:soil], "channel 1 is duplicated"
  end

  test "rejects out-of-range soil channel" do
    measurement = WeatherMeasurement.new(valid_attrs(
      soil: [ { "channel" => 9, "moisture" => 78.0, "battery" => 1.6 } ]
    ))

    assert_not measurement.valid?
    assert_includes measurement.errors[:soil], "channel must be an integer between 1 and 8"
  end

  test "rejects non-numeric soil moisture or battery" do
    measurement = WeatherMeasurement.new(valid_attrs(
      soil: [ { "channel" => 1, "moisture" => "wet", "battery" => 1.6 } ]
    ))

    assert_not measurement.valid?
    assert_includes measurement.errors[:soil], "moisture must be a number"
  end

  test "rejects negative soil battery" do
    measurement = WeatherMeasurement.new(valid_attrs(
      soil: [ { "channel" => 1, "moisture" => 78.0, "battery" => -0.1 } ]
    ))

    assert_not measurement.valid?
    assert_includes measurement.errors[:soil], "battery must be greater than or equal to 0"
  end

  test "accepts soil temperature without moisture" do
    measurement = WeatherMeasurement.new(valid_attrs(
      soil: [ { "channel" => 1, "temperature" => 12.5, "battery" => 1.6 } ]
    ))

    assert measurement.valid?
    assert_equal 12.5, measurement.soil.first["temperature"]
  end

  test "soil_readings converts legacy soil temperature to fahrenheit" do
    measurement = WeatherMeasurement.new(valid_attrs(
      soil: [ { "channel" => 1, "moisture" => 78.0, "temperature" => 10.0, "battery" => 1.6 } ]
    ))

    assert measurement.valid?
    reading = measurement.soil_readings.first
    assert_equal 1, reading["channel"]
    assert_equal 78, reading["moisture"]
    assert_equal 50, reading["temperature_f"]
    assert_equal 1.6, reading["moisture_battery"]
    assert_nil reading["temperature_battery"]
  end

  test "legacy soil temperature-only battery appears under temp column" do
    measurement = WeatherMeasurement.new(valid_attrs(
      soil: [ { "channel" => 1, "temperature" => 10.0, "battery" => 1.6 } ]
    ))

    reading = measurement.soil_readings.first
    assert_equal 50, reading["temperature_f"]
    assert_equal 1.6, reading["temperature_battery"]
    assert_nil reading["moisture"]
    assert_nil reading["moisture_battery"]
  end

  test "soil_readings prefers temp_probe temperature over legacy soil temperature" do
    SoilChannels.instance_variable_set(:@soil_names, { 1 => "Front Yard" })
    SoilChannels.instance_variable_set(:@temp_probe_names, { 2 => "Front Yard" })

    measurement = WeatherMeasurement.new(valid_attrs(
      soil: [ { "channel" => 1, "moisture" => 62.0, "temperature" => 0.0, "battery" => 1.6 } ],
      temp_probes: [ { "channel" => 2, "temperature" => 10.0, "battery" => 1.4 } ]
    ))

    reading = measurement.soil_readings.first
    assert_equal "Front Yard", reading["name"]
    assert_equal 62, reading["moisture"]
    assert_equal 1.6, reading["moisture_battery"]
    assert_equal 50, reading["temperature_f"]
    assert_equal 1.4, reading["temperature_battery"]
  ensure
    SoilChannels.reload!
  end

  test "soil_readings merges using committed site channel groupings" do
    SoilChannels.config_path = Rails.root.join("config/soil_channels.yml")
    SoilChannels.reload!

    measurement = WeatherMeasurement.new(valid_attrs(
      soil: [
        { "channel" => 1, "moisture" => 70.0, "battery" => 1.6 },
        { "channel" => 2, "moisture" => 55.0, "battery" => 1.58 },
        { "channel" => 3, "moisture" => 40.0, "battery" => 1.5 }
      ],
      temp_probes: [
        { "channel" => 1, "temperature" => 12.0, "battery" => 1.4 },
        { "channel" => 2, "temperature" => 10.0, "battery" => 1.45 }
      ]
    ))

    readings = measurement.soil_readings.index_by { |reading| reading["name"] }

    assert_equal [ "Veggie Bed", "Front Yard", "Back Yard" ], measurement.soil_readings.map { |r| r["name"] }

    assert_equal 70, readings["Veggie Bed"]["moisture"]
    assert_nil readings["Veggie Bed"]["temperature_f"]

    assert_equal 55, readings["Front Yard"]["moisture"]
    assert_equal 50, readings["Front Yard"]["temperature_f"]
    assert_equal 1.58, readings["Front Yard"]["moisture_battery"]
    assert_equal 1.45, readings["Front Yard"]["temperature_battery"]

    assert_equal 40, readings["Back Yard"]["moisture"]
    assert_equal 54, readings["Back Yard"]["temperature_f"] # 12°C
    assert_equal 1.4, readings["Back Yard"]["temperature_battery"]
  ensure
    SoilChannels.config_path = nil
    SoilChannels.reload!
  end

  test "accepts valid temp_probes" do
    measurement = WeatherMeasurement.new(valid_attrs(
      temp_probes: [
        { "channel" => 1, "temperature" => 12.5, "battery" => 1.55 },
        { "channel" => 2, "temperature" => 11.0 }
      ]
    ))

    assert measurement.valid?
    assert_equal 2, measurement.temp_probes.size
    assert_equal 12.5, measurement.temp_probes.first["temperature"]
  end

  test "rejects temp_probes without temperature" do
    measurement = WeatherMeasurement.new(valid_attrs(
      temp_probes: [ { "channel" => 1, "battery" => 1.55 } ]
    ))

    assert_not measurement.valid?
    assert_includes measurement.errors[:temp_probes], "temperature must be a number"
  end

  test "rejects duplicate temp_probe channels" do
    measurement = WeatherMeasurement.new(valid_attrs(
      temp_probes: [
        { "channel" => 1, "temperature" => 12.5 },
        { "channel" => 1, "temperature" => 11.0 }
      ]
    ))

    assert_not measurement.valid?
    assert_includes measurement.errors[:temp_probes], "channel 1 is duplicated"
  end

  test "soil_readings includes friendly channel name" do
    SoilChannels.instance_variable_set(:@soil_names, { 1 => "Raised bed" })
    SoilChannels.instance_variable_set(:@temp_probe_names, {})

    measurement = WeatherMeasurement.new(valid_attrs(
      soil: [ { "channel" => 1, "moisture" => 78.0, "battery" => 1.6 } ]
    ))

    assert_equal "Raised bed", measurement.soil_readings.first["name"]
  ensure
    SoilChannels.reload!
  end

  test "soil_readings merges soil and temp_probe channels that share a friendly name" do
    SoilChannels.instance_variable_set(:@soil_names, { 1 => "Front Yard" })
    SoilChannels.instance_variable_set(:@temp_probe_names, { 2 => "Front Yard" })

    measurement = WeatherMeasurement.new(valid_attrs(
      soil: [ { "channel" => 1, "moisture" => 62.0, "battery" => 1.6 } ],
      temp_probes: [ { "channel" => 2, "temperature" => 10.0, "battery" => 1.4 } ]
    ))

    assert measurement.valid?
    readings = measurement.soil_readings
    assert_equal 1, readings.size
    reading = readings.first
    assert_equal "Front Yard", reading["name"]
    assert_equal 1, reading["channel"]
    assert_equal 62, reading["moisture"]
    assert_equal 1.6, reading["moisture_battery"]
    assert_equal 50, reading["temperature_f"]
    assert_equal 1.4, reading["temperature_battery"]
  ensure
    SoilChannels.reload!
  end

  test "soil_readings keeps distinct names as separate rows" do
    SoilChannels.instance_variable_set(:@soil_names, { 1 => "Raised bed", 2 => "Tomato pots" })
    SoilChannels.instance_variable_set(:@temp_probe_names, {})

    measurement = WeatherMeasurement.new(valid_attrs(
      soil: [
        { "channel" => 1, "moisture" => 78.0, "battery" => 1.6 },
        { "channel" => 2, "moisture" => 55.0, "battery" => 1.5 }
      ]
    ))

    readings = measurement.soil_readings
    assert_equal 2, readings.size
    assert_equal [ "Raised bed", "Tomato pots" ], readings.map { |reading| reading["name"] }
  ensure
    SoilChannels.reload!
  end

  test "soil_readings does not merge unconfigured soil and temp probe channel 1" do
    SoilChannels.instance_variable_set(:@soil_names, {})
    SoilChannels.instance_variable_set(:@temp_probe_names, {})

    measurement = WeatherMeasurement.new(valid_attrs(
      soil: [ { "channel" => 1, "moisture" => 70.0, "battery" => 1.6 } ],
      temp_probes: [ { "channel" => 1, "temperature" => 10.0, "battery" => 1.5 } ]
    ))

    readings = measurement.soil_readings
    assert_equal 2, readings.size
    assert_equal [ "Ch 1", "Temp Ch 1" ], readings.map { |reading| reading["name"] }
  ensure
    SoilChannels.reload!
  end

  test "soil_readings prefers moisture from lower channel when both report it" do
    SoilChannels.instance_variable_set(:@soil_names, { 2 => "Bed", 3 => "Bed" })
    SoilChannels.instance_variable_set(:@temp_probe_names, {})

    measurement = WeatherMeasurement.new(valid_attrs(
      soil: [
        { "channel" => 3, "moisture" => 40.0, "battery" => 1.6 },
        { "channel" => 2, "moisture" => 70.0, "battery" => 1.5 }
      ]
    ))

    reading = measurement.soil_readings.first
    assert_equal 70, reading["moisture"]
    assert_equal 2, reading["channel"]
    assert_equal 1.5, reading["moisture_battery"]
  ensure
    SoilChannels.reload!
  end

  test "broadcast payload includes live sparkline series" do
    travel_to Time.utc(2026, 7, 13, 21, 30, 0) do
      WeatherMeasurement.create!(valid_attrs(humidity: 55, reading_date_time: 10.minutes.ago))
      WeatherMeasurement.create!(valid_attrs(humidity: 50))

      current = WeatherMeasurement.order(reading_date_time: :desc).first
      payload = WeatherMeasurements::LiveUpdateBroadcast.new.send(:payload, current)

      assert payload[:sparklines].is_a?(Hash)
      assert_equal 144, payload[:sparklines][:humidity][:labels].length
      assert_includes payload[:sparklines][:humidity][:values], 50
      assert_equal WeatherMeasurement.count, payload[:counter]
    end
  end
end

