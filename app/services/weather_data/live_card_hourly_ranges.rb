# frozen_string_literal: true

# Builds last-24h hourly series for the home-page live cards.
# Each hour contributes its average as the plotted point. The Y-axis
# range is the overall lowest low and highest high across the window.
# Weather metrics come from WeatherMeasurement; AQI from Aqi (already hourly).
module WeatherData
  class LiveCardHourlyRanges
    HOURS = 24
    MM_TO_IN = 25.4
    MPS_TO_MPH = 2.23694
    CLOUD_BASE_FT_PER_C_SPREAD = (9.0 / 5.0) * 227.3

    def initialize(now: Time.current)
      @now = now
      # Normalize to UTC hour buckets so SQL date_trunc keys match.
      @start_hour = (now.utc - (HOURS - 1).hours).beginning_of_hour
      @end_hour = now.utc.beginning_of_hour
    end

    def call
      weather = weather_buckets
      aqi = aqi_buckets

      {
        wind: wind_series_for(weather, decimals: 0),
        humidity: series_for(weather, :humidity_avg, :humidity_high, :humidity_low, decimals: 0),
        uvi: series_for(weather, :uvi_avg, :uvi_high, :uvi_low, decimals: 0),
        rain_rate: series_for(weather, :rain_avg, :rain_high, :rain_low, decimals: 2),
        dew_point: series_for(weather, :dew_avg, :dew_high, :dew_low, decimals: 0),
        cloud_base: series_for(weather, :cloud_avg, :cloud_high, :cloud_low, decimals: 0),
        aqi: series_for(aqi, :aqi_avg, :aqi_high, :aqi_low, decimals: 0)
      }
    end

    private

    attr_reader :now, :start_hour, :end_hour

    def hour_keys
      @hour_keys ||= (0...HOURS).map { |i| start_hour + i.hours }
    end

    # Wind plots hourly average speed as the line; peak gust each hour is
    # returned separately so the sparkline can draw it as a dashed companion.
    def wind_series_for(buckets, decimals:)
      series = series_for(buckets, :wind_avg, :wind_high, :wind_low, decimals: decimals)
      return nil if series.nil?

      series.merge(
        markers: hour_keys.map { |h| round_value(buckets.dig(h, :wind_high), decimals) }
      )
    end

    def series_for(buckets, avg_key, high_key, low_key, decimals:)
      values = hour_keys.map { |h| round_value(buckets.dig(h, avg_key), decimals) }
      return nil if values.compact.length < 2

      highs = hour_keys.filter_map { |h| buckets.dig(h, high_key) }
      lows = hour_keys.filter_map { |h| buckets.dig(h, low_key) }

      {
        labels: hour_keys.map { |h| hour_label(h) },
        values: values,
        y_min: round_value(lows.min, decimals),
        y_max: round_value(highs.max, decimals)
      }
    end

    def hour_label(utc_hour)
      # "12 pm", "3 am" — hour only, no minutes, Pacific local time.
      utc_hour.in_time_zone("America/Los_Angeles").strftime("%-l %P").strip
    end

    def round_value(value, decimals)
      return nil if value.nil?

      value.to_f.round(decimals)
    end

    def weather_buckets
      dew_expr = "temperature - ((100.0 - humidity) / 5.0)"
      # Same approximation as ConditionsComponent#current_cloud_base_ft:
      # spread_F = (T_C - Td_C) * 9/5 = ((100 - RH) / 5) * 9/5
      cloud_expr = "GREATEST(((100.0 - humidity) / 5.0) * #{CLOUD_BASE_FT_PER_C_SPREAD}, 0)"

      rows = WeatherMeasurement
        .where(reading_date_time: start_hour..(end_hour + 1.hour - 1.second))
        .group(Arel.sql("date_trunc('hour', reading_date_time)"))
        .order(Arel.sql("date_trunc('hour', reading_date_time)"))
        .pluck(
          Arel.sql("date_trunc('hour', reading_date_time)"),
          Arel.sql("AVG(wind_speed)"),
          Arel.sql("MAX(gust_speed)"),
          Arel.sql("MIN(wind_speed)"),
          Arel.sql("AVG(humidity)"),
          Arel.sql("MAX(humidity)"),
          Arel.sql("MIN(humidity)"),
          Arel.sql("AVG(uvi)"),
          Arel.sql("MAX(uvi)"),
          Arel.sql("MIN(uvi)"),
          Arel.sql("AVG(rain_rate)"),
          Arel.sql("MAX(rain_rate)"),
          Arel.sql("MIN(rain_rate)"),
          Arel.sql("AVG(#{dew_expr})"),
          Arel.sql("MAX(#{dew_expr})"),
          Arel.sql("MIN(#{dew_expr})"),
          Arel.sql("AVG(#{cloud_expr})"),
          Arel.sql("MAX(#{cloud_expr})"),
          Arel.sql("MIN(#{cloud_expr})")
        )

      rows.each_with_object({}) do |(hour, wind_avg, wind_hi, wind_lo, hum_avg, hum_hi, hum_lo, uvi_avg, uvi_hi, uvi_lo, rain_avg, rain_hi, rain_lo, dew_avg, dew_hi, dew_lo, cloud_avg, cloud_hi, cloud_lo), memo|
        key = normalize_hour(hour)
        memo[key] = {
          # Y-axis high uses peak gust; low/avg use sustained wind speed.
          wind_avg: wind_avg ? wind_avg * MPS_TO_MPH : nil,
          wind_high: wind_hi ? wind_hi * MPS_TO_MPH : nil,
          wind_low: wind_lo ? wind_lo * MPS_TO_MPH : nil,
          humidity_avg: hum_avg,
          humidity_high: hum_hi,
          humidity_low: hum_lo,
          uvi_avg: uvi_avg,
          uvi_high: uvi_hi,
          uvi_low: uvi_lo,
          rain_avg: rain_avg ? rain_avg / MM_TO_IN : nil,
          rain_high: rain_hi ? rain_hi / MM_TO_IN : nil,
          rain_low: rain_lo ? rain_lo / MM_TO_IN : nil,
          dew_avg: dew_avg ? c_to_f(dew_avg) : nil,
          dew_high: dew_hi ? c_to_f(dew_hi) : nil,
          dew_low: dew_lo ? c_to_f(dew_lo) : nil,
          cloud_avg: cloud_avg,
          cloud_high: cloud_hi,
          cloud_low: cloud_lo
        }
      end
    end

    def aqi_buckets
      rows = Aqi.with_observation
        .where(observed_at: start_hour..(end_hour + 1.hour - 1.second))
        .pluck(:observed_at, :epa_aqi, :pm2_5)

      rows.each_with_object({}) do |(observed_at, epa_aqi, pm2_5), memo|
        key = normalize_hour(observed_at)
        value = epa_aqi.presence || Aqi.epa_aqi_from_pm25(pm2_5)
        next if value.nil?

        bucket = memo[key]
        if bucket.nil?
          memo[key] = { aqi_avg: value, aqi_high: value, aqi_low: value, aqi_count: 1 }
        else
          n = bucket[:aqi_count]
          bucket[:aqi_avg] = ((bucket[:aqi_avg] * n) + value) / (n + 1.0)
          bucket[:aqi_count] = n + 1
          bucket[:aqi_high] = [ bucket[:aqi_high], value ].max
          bucket[:aqi_low] = [ bucket[:aqi_low], value ].min
        end
      end
    end

    def normalize_hour(time)
      t = time.respond_to?(:utc) ? time.utc : Time.parse(time.to_s).utc
      t.beginning_of_hour
    end

    def c_to_f(celsius)
      celsius * 9.0 / 5.0 + 32.0
    end
  end
end
