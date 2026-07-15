# frozen_string_literal: true

# Builds today-so-far 10-minute series for the home-page live cards.
# The X-axis is the absolute local calendar day (00:00 → 23:50). As the
# day progresses, completed buckets fill in; future buckets stay empty.
# Each bucket contributes its average as the plotted point. The Y-axis
# range is the overall lowest low and highest high across buckets with data.
# Weather metrics come from WeatherMeasurement; AQI from Aqi.
module WeatherData
  class LiveCardHourlyRanges
    ZONE = "America/Los_Angeles"
    INTERVAL_MINUTES = 10
    BUCKETS_PER_DAY = (24 * 60) / INTERVAL_MINUTES
    MM_TO_IN = 25.4
    MPS_TO_MPH = 2.23694
    CLOUD_BASE_FT_PER_C_SPREAD = (9.0 / 5.0) * 227.3

    BUCKET_SQL = <<~SQL.squish.freeze
      date_trunc('hour', reading_date_time)
        + (FLOOR(EXTRACT(MINUTE FROM reading_date_time) / #{INTERVAL_MINUTES})
           * INTERVAL '#{INTERVAL_MINUTES} minutes')
    SQL

    def initialize(now: Time.current)
      @now = now
      local = now.in_time_zone(ZONE)
      day_start = local.beginning_of_day
      # Normalize to UTC bucket keys so SQL aggregates match Ruby keys.
      @start_bucket = day_start.utc
      @end_bucket = bucket_floor(local).utc
      @bucket_keys = (0...BUCKETS_PER_DAY).map { |i| (day_start + (i * INTERVAL_MINUTES).minutes).utc }
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

    attr_reader :now, :start_bucket, :end_bucket, :bucket_keys

    # Wind plots bucket-average speed as the line; peak gust each bucket is
    # returned separately so the sparkline can draw it as a dashed companion.
    def wind_series_for(buckets, decimals:)
      series = series_for(buckets, :wind_avg, :wind_high, :wind_low, decimals: decimals)
      series.merge(
        markers: bucket_keys.map { |b| value_for_bucket(b, buckets.dig(b, :wind_high), decimals) }
      )
    end

    def series_for(buckets, avg_key, high_key, low_key, decimals:)
      values = bucket_keys.map { |b| value_for_bucket(b, buckets.dig(b, avg_key), decimals) }
      highs = bucket_keys.filter_map { |b| buckets.dig(b, high_key) if b <= end_bucket }
      lows = bucket_keys.filter_map { |b| buckets.dig(b, low_key) if b <= end_bucket }

      series = {
        labels: bucket_keys.map { |b| bucket_label(b) },
        values: values
      }
      if lows.any? && highs.any?
        series[:y_min] = round_value(lows.min, decimals)
        series[:y_max] = round_value(highs.max, decimals)
      end
      series
    end

    # Future buckets of the local day stay blank so the sparkline fills left-to-right.
    def value_for_bucket(bucket, value, decimals)
      return nil if bucket > end_bucket

      round_value(value, decimals)
    end

    def bucket_label(utc_bucket)
      # "12:00 am", "2:30 pm" — Pacific local time at 10-minute resolution.
      utc_bucket.in_time_zone(ZONE).strftime("%-l:%M %P").strip
    end

    def bucket_floor(time)
      t = time.respond_to?(:utc) ? time.utc : Time.parse(time.to_s).utc
      minutes = (t.min / INTERVAL_MINUTES) * INTERVAL_MINUTES
      Time.utc(t.year, t.month, t.day, t.hour, minutes, 0)
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
        .where(reading_date_time: start_bucket..(end_bucket + INTERVAL_MINUTES.minutes - 1.second))
        .group(Arel.sql(BUCKET_SQL))
        .order(Arel.sql(BUCKET_SQL))
        .pluck(
          Arel.sql(BUCKET_SQL),
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

      rows.each_with_object({}) do |(bucket, wind_avg, wind_hi, wind_lo, hum_avg, hum_hi, hum_lo, uvi_avg, uvi_hi, uvi_lo, rain_avg, rain_hi, rain_lo, dew_avg, dew_hi, dew_lo, cloud_avg, cloud_hi, cloud_lo), memo|
        key = normalize_bucket(bucket)
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
        .where(observed_at: start_bucket..(end_bucket + INTERVAL_MINUTES.minutes - 1.second))
        .pluck(:observed_at, :epa_aqi, :pm2_5)

      rows.each_with_object({}) do |(observed_at, epa_aqi, pm2_5), memo|
        key = normalize_bucket(observed_at)
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

    def normalize_bucket(time)
      bucket_floor(time)
    end

    def c_to_f(celsius)
      celsius * 9.0 / 5.0 + 32.0
    end
  end
end
