module Reports
  class OverviewStatisticsTableComponent < ViewComponent::Base
    include UnitConversions

    Snapshot = Struct.new(
      :mean_temp, :high_temp, :high_meta, :low_temp, :low_meta,
      :heat_dd, :cool_dd, :rain,
      :mean_pressure, :high_pressure, :high_pressure_meta,
      :low_pressure, :low_pressure_meta,
      :avg_wind, :high_wind, :high_wind_meta,
      :wind_label, :wind_degrees,
      keyword_init: true
    )

    def initialize(report:, type: :monthly, day: nil)
      @report = report
      @type = type
      @day = day
    end

    private

    attr_reader :report, :type, :day

    def daily?
      type == :daily
    end

    # The day page used to render this with the month's totals, so a dry day
    # showed the month's rain (and every other monthly stat) as "today".
    def snapshot
      return monthly_snapshot unless daily?

      entry = daily_entry
      return nil unless entry

      Snapshot.new(
        mean_temp: entry.mean_temp,
        high_temp: entry.high_temp,
        high_meta: meta_for(entry.high_temp_time),
        low_temp: entry.low_temp,
        low_meta: meta_for(entry.low_temp_time),
        heat_dd: entry.heat_degree_days,
        cool_dd: entry.cool_degree_days,
        rain: entry.rain,
        mean_pressure: entry.mean_pressure,
        high_pressure: entry.high_pressure,
        high_pressure_meta: meta_for(entry.high_pressure_time),
        low_pressure: entry.low_pressure,
        low_pressure_meta: meta_for(entry.low_pressure_time),
        avg_wind: entry.avg_wind_speed,
        high_wind: entry.high_wind_speed,
        high_wind_meta: meta_for(entry.high_wind_time),
        wind_label: entry.formatted_wind_dir,
        wind_degrees: entry.wind_dir
      )
    end

    def monthly_snapshot
      Snapshot.new(
        mean_temp: report.month_mean_temp,
        high_temp: report.month_high_temp,
        high_meta: meta_for(report.month_high_temp_day),
        low_temp: report.month_low_temp,
        low_meta: meta_for(report.month_low_temp_day),
        heat_dd: report.total_heat_degree_days,
        cool_dd: report.total_cool_degree_days,
        rain: report.total_rain,
        mean_pressure: report.month_mean_pressure,
        high_pressure: report.month_high_pressure,
        high_pressure_meta: meta_for(report.month_high_pressure_day),
        low_pressure: report.month_low_pressure,
        low_pressure_meta: meta_for(report.month_low_pressure_day),
        avg_wind: report.avg_wind_speed,
        high_wind: report.month_high_wind_speed,
        high_wind_meta: meta_for(report.month_high_wind_day),
        wind_label: report.formatted_dominant_wind,
        wind_degrees: report.dominant_wind_dir
      )
    end

    def daily_entry
      report.entries.find { |entry| entry.hour.nil? && entry.day == day }
    end

    def meta_for(value)
      label = value.presence || "N/A"
      daily? ? "(@ #{label})" : "(Day #{label})"
    end
  end
end
