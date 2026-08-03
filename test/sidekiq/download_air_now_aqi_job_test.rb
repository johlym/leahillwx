# frozen_string_literal: true

require "test_helper"

class DownloadAirNowAqiJobTest < ActiveSupport::TestCase
  def stub_observation(readings_by_hour)
    fake = Object.new
    fake.define_singleton_method(:fetch_reading) do |time|
      hour = time.utc.change(min: 0, sec: 0)
      readings_by_hour[hour]
    end

    AirNowHourlyObservation.singleton_class.alias_method(:__orig_new, :new)
    AirNowHourlyObservation.define_singleton_method(:new) { |*_args, **_kwargs| fake }
    begin
      yield
    ensure
      AirNowHourlyObservation.singleton_class.remove_method(:new)
      AirNowHourlyObservation.singleton_class.alias_method(:new, :__orig_new)
      AirNowHourlyObservation.singleton_class.remove_method(:__orig_new)
    end
  end

  test "upserts AirNow readings found in the lookback window" do
    hour = Time.utc(2026, 8, 3, 18, 0, 0)
    travel_to hour + 20.minutes do
      reading = {
        observed_at: hour - 1.hour,
        pm2_5: 4.2,
        epa_aqi: 18,
        source: "airnow"
      }

      assert_difference "Aqi.count", 1 do
        stub_observation({ (hour - 1.hour) => reading }) do
          DownloadAirNowAqiJob.new.perform
        end
      end

      record = Aqi.find_by!(observed_at: hour - 1.hour)
      assert_equal "airnow", record.source
      assert_in_delta 4.2, record.pm2_5, 0.001
      assert_equal 18, record.epa_aqi
    end
  end

  test "no-ops when AirNow has no PM2.5 in the lookback window" do
    travel_to Time.utc(2026, 8, 3, 18, 20, 0) do
      assert_no_difference "Aqi.count" do
        stub_observation({}) { DownloadAirNowAqiJob.new.perform }
      end
    end
  end

  test "overwrites an openweather row for the same hour" do
    hour = Time.utc(2026, 8, 3, 17, 0, 0)
    Aqi.upsert_reading!(observed_at: hour, pm2_5: 9.0, source: "openweather")

    travel_to hour + 1.hour + 20.minutes do
      reading = {
        observed_at: hour,
        pm2_5: 2.1,
        epa_aqi: 11,
        source: "airnow"
      }

      assert_no_difference "Aqi.count" do
        stub_observation({ hour => reading }) do
          DownloadAirNowAqiJob.new.perform
        end
      end
    end

    record = Aqi.find_by!(observed_at: hour)
    assert_equal "airnow", record.source
    assert_in_delta 2.1, record.pm2_5, 0.001
    assert_equal 11, record.epa_aqi
  end

  test "continues lookback when an earlier hour fetch raises" do
    hour = Time.utc(2026, 8, 3, 18, 0, 0)
    good = {
      observed_at: hour - 2.hours,
      pm2_5: 3.0,
      epa_aqi: 13,
      source: "airnow"
    }

    travel_to hour + 20.minutes do
      call_count = 0
      fake = Object.new
      fake.define_singleton_method(:fetch_reading) do |time|
        call_count += 1
        raise StandardError, "S3 timeout" if time.utc == hour

        good if time.utc == hour - 2.hours
      end

      AirNowHourlyObservation.singleton_class.alias_method(:__orig_new, :new)
      AirNowHourlyObservation.define_singleton_method(:new) { |*_args, **_kwargs| fake }
      begin
        assert_difference "Aqi.count", 1 do
          DownloadAirNowAqiJob.new.perform
        end
      ensure
        AirNowHourlyObservation.singleton_class.remove_method(:new)
        AirNowHourlyObservation.singleton_class.alias_method(:new, :__orig_new)
        AirNowHourlyObservation.singleton_class.remove_method(:__orig_new)
      end

      assert call_count >= 3
      assert_equal "airnow", Aqi.find_by!(observed_at: hour - 2.hours).source
    end
  end
end
