module ReportsHelper
  def format_text_row(day, entry, report)
    if entry.nil? || !entry.has_data?
      # Future day or completely missing day
      if day > Time.zone.today.day && report.year == Time.zone.today.year && report.month == Time.zone.today.month
        format("%3d", day)
      else
        format("%3d %6s %6s %5s %6s %5s %6s %6s %6s %6s %6s %6s %5s %6s %5s %5s %10s",
               day, "N/A", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A")
      end
    else
      partial_indicator = entry.partial_period ? "*" : ""

      format(
        "%3d %6s %6s %5s %6s %5s %6s %6s %6s %6s %6s %6s %5s %6s %5s %5s %10s%s",
        day,
        entry.formatted_temp(entry.mean_temp),
        entry.formatted_temp(entry.high_temp),
        entry.high_temp_time || "N/A",
        entry.formatted_temp(entry.low_temp),
        entry.low_temp_time || "N/A",
        entry.formatted_degree_days(entry.heat_degree_days),
        entry.formatted_degree_days(entry.cool_degree_days),
        entry.formatted_rain,
        entry.formatted_pressure(entry.mean_pressure),
        entry.formatted_pressure(entry.high_pressure),
        entry.high_pressure_time || "N/A",
        entry.formatted_pressure(entry.low_pressure),
        entry.low_pressure_time || "N/A",
        entry.formatted_wind_speed(entry.avg_wind_speed),
        entry.formatted_wind_speed(entry.high_wind_speed),
        entry.high_wind_time || "N/A",
        entry.formatted_wind_dir,
        partial_indicator
      )
    end
  end

  def format_hourly_text_row(hour, entry, report, day)
    now = Time.current.in_time_zone("America/Los_Angeles")

    if entry.nil? || !entry.has_data?
      # Future hour or completely missing hour
      if hour > now.hour && day == now.day && report.year == now.year && report.month == now.month
        format("%4d", hour)
      else
        format("%4d %6s %6s %5s %6s %5s %6s %6s %6s %6s %6s %6s %5s %6s %5s %5s %10s",
               hour, "N/A", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A")
      end
    else
      partial_indicator = entry.partial_period ? "*" : ""

      format(
        "%4d %6s %6s %5s %6s %5s %6s %6s %6s %6s %6s %6s %5s %6s %5s %5s %10s%s",
        hour,
        entry.formatted_temp(entry.mean_temp),
        entry.formatted_temp(entry.high_temp),
        entry.high_temp_time || "N/A",
        entry.formatted_temp(entry.low_temp),
        entry.low_temp_time || "N/A",
        entry.formatted_degree_days(entry.heat_degree_days),
        entry.formatted_degree_days(entry.cool_degree_days),
        entry.formatted_rain,
        entry.formatted_pressure(entry.mean_pressure),
        entry.formatted_pressure(entry.high_pressure),
        entry.high_pressure_time || "N/A",
        entry.formatted_pressure(entry.low_pressure),
        entry.low_pressure_time || "N/A",
        entry.formatted_wind_speed(entry.avg_wind_speed),
        entry.formatted_wind_speed(entry.high_wind_speed),
        entry.high_wind_time || "N/A",
        entry.formatted_wind_dir,
        partial_indicator
      )
    end
  end

  def has_partial_days?(report)
    report.entries.any?(&:partial_period)
  end
end
