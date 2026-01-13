module ReportsHelper
  def format_text_row(day, entry, report)
    if entry.nil? || !entry.has_data?
      # Future day or completely missing day
      if day > Date.today.day && report.year == Date.today.year && report.month == Date.today.month
        format(" %2d", day)
      else
        format(" %2d   %-6s  %-6s  %-6s  %-6s  %-6s  %-6s  %-6s  %-6s  %-6s  %-6s  %-6s  %-8s",
               day, "N/A", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A")
      end
    else
      partial_indicator = entry.partial_day ? "*" : ""

      format(
        " %2d  %6s  %6s  %5s  %6s  %5s  %6s  %6s  %6s  %6s  %6s  %5s  %8s%s",
        day,
        entry.formatted_temp(entry.mean_temp),
        entry.formatted_temp(entry.high_temp),
        entry.high_temp_time || "  N/A",
        entry.formatted_temp(entry.low_temp),
        entry.low_temp_time || "  N/A",
        entry.formatted_degree_days(entry.heat_degree_days),
        entry.formatted_degree_days(entry.cool_degree_days),
        entry.formatted_rain,
        entry.formatted_wind_speed(entry.avg_wind_speed),
        entry.formatted_wind_speed(entry.high_wind_speed),
        entry.high_wind_time || "  N/A",
        entry.formatted_wind_dir,
        partial_indicator
      )
    end
  end

  def has_partial_days?(report)
    report.entries.any?(&:partial_day)
  end
end
