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
#  rain_day          :float            default(0.0)
#  rain_rate         :float            not null
#  reading_date_time :datetime         not null
#  soil              :jsonb            not null
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
#  index_weather_measurements_on_reading_date_time  (reading_date_time)
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

  test "accepts soil temperature without moisture" do
    measurement = WeatherMeasurement.new(valid_attrs(
      soil: [ { "channel" => 1, "temperature" => 12.5, "battery" => 1.6 } ]
    ))

    assert measurement.valid?
    assert_equal 12.5, measurement.soil.first["temperature"]
  end

  test "soil_readings converts temperature to fahrenheit" do
    measurement = WeatherMeasurement.new(valid_attrs(
      soil: [ { "channel" => 1, "moisture" => 78.0, "temperature" => 10.0, "battery" => 1.6 } ]
    ))

    assert measurement.valid?
    reading = measurement.soil_readings.first
    assert_equal 1, reading["channel"]
    assert_equal 78, reading["moisture"]
    assert_equal 50, reading["temperature_f"]
  end

  test "soil_readings includes friendly channel name" do
    SoilChannels.instance_variable_set(:@names, { 1 => "Raised bed" })

    measurement = WeatherMeasurement.new(valid_attrs(
      soil: [ { "channel" => 1, "moisture" => 78.0, "battery" => 1.6 } ]
    ))

    assert_equal "Raised bed", measurement.soil_readings.first["name"]
  ensure
    SoilChannels.reload!
  end
end


