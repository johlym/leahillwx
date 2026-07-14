# frozen_string_literal: true

require "csv"

# Fetches and parses AirNow HourlyAQObs CSV files for a single AQSID
# (default: Auburn 29th St).
#
# URL pattern:
#   https://s3-us-west-1.amazonaws.com/files.airnowtech.org/airnow/{YYYY}/{YYYYMMDD}/HourlyAQObs_{YYYYMMDDHH}.dat
class AirNowHourlyObsService
  BASE_URL = "https://s3-us-west-1.amazonaws.com/files.airnowtech.org"
  DEFAULT_AQSID = "840530330047"

  def initialize(aqsid: nil)
    @aqsid = aqsid.presence || ENV.fetch("AIRNOW_AQSID", DEFAULT_AQSID)
  end

  attr_reader :aqsid

  def url_for(time)
    utc = time.utc
    day = utc.strftime("%Y/%Y%m%d")
    stamp = utc.strftime("%Y%m%d%H")
    "#{BASE_URL}/airnow/#{day}/HourlyAQObs_#{stamp}.dat"
  end

  # Returns a hash suitable for Aqi.upsert_reading!, or nil if the
  # station/hour has no PM2.5 reading in the file.
  def fetch_reading(time)
    response = HTTParty.get(url_for(time), timeout: 60)
    return nil unless response.success?

    parse_reading(response.body, expected_time: time.utc)
  end

  def parse_reading(csv_body, expected_time: nil)
    CSV.parse(csv_body, headers: true).each do |row|
      next unless row["AQSID"].to_s == aqsid.to_s

      pm25 = blank_to_nil(row["PM25"])
      next if pm25.nil?

      observed_at = parse_observed_at(row["ValidDate"], row["ValidTime"])
      next if observed_at.nil?
      next if expected_time && observed_at != expected_time.utc.change(min: 0, sec: 0)

      return {
        observed_at: observed_at,
        pm2_5: pm25.to_f,
        epa_aqi: blank_to_nil(row["PM25_AQI"])&.to_i,
        source: "airnow"
      }
    end

    nil
  end

  private

  def blank_to_nil(value)
    return nil if value.nil?

    str = value.to_s.strip
    str.empty? ? nil : str
  end

  # ValidDate is mm/dd/yyyy (or mm/dd/yy); ValidTime is HH:MM in GMT
  # and marks the beginning of the measurement hour.
  def parse_observed_at(valid_date, valid_time)
    return nil if valid_date.blank? || valid_time.blank?

    date = Date.strptime(valid_date.strip, valid_date.strip.length <= 8 ? "%m/%d/%y" : "%m/%d/%Y")
    hour, minute = valid_time.strip.split(":").map(&:to_i)
    Time.utc(date.year, date.month, date.day, hour, minute || 0, 0)
  rescue ArgumentError
    nil
  end
end
