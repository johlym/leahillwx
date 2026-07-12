module DateTimeFormatting
  TIMEZONE = "America/Los_Angeles"

  # Time only, always local, always 12-hour with AM/PM.
  # Example: "07:32 AM"
  def format_time(time, strip_leading_zero: false)
    return "N/A" unless time
    fmt = strip_leading_zero ? "%-I:%M %p" : "%I:%M %p"
    time.in_time_zone(TIMEZONE).strftime(fmt)
  end

  # Date only. Example: "Aug 12, 2025"
  def format_date(date)
    return "N/A" unless date
    date.strftime("%b %d, %Y")
  end

  # Combined date + time. Example: "Aug 12, 25 @ 07:32 AM"
  # `style: :long` extends to a four-digit year for prose contexts.
  def format_datetime(datetime, style: :short)
    return "N/A" unless datetime
    local = datetime.in_time_zone(TIMEZONE)
    year_fmt = style == :long ? "%Y" : "%y"
    local.strftime("%b %d, #{year_fmt} @ %I:%M %p")
  end

  # Degrees suffix. Callers that want a temperature should NOT include
  # "F" — the surrounding UI carries the unit. This helper is used for
  # angles (heading, altitude) which are always degree-symbol only.
  def format_degrees(degrees)
    return "N/A" unless degrees
    "#{degrees.round(1)}°"
  end
end
