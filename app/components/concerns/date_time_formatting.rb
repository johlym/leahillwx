module DateTimeFormatting
  TIMEZONE = "America/Los_Angeles"

  def format_time(time, strip_leading_zero: false)
    return "N/A" unless time
    format = strip_leading_zero ? "%-I:%M %p" : "%I:%M %p"
    time.in_time_zone(TIMEZONE).strftime(format)
  end

  def format_date(date)
    return "N/A" unless date
    date.strftime("%b %d, %Y")
  end

  def format_datetime(datetime, style: :short)
    return "N/A" unless datetime
    format = style == :numeric ? "%m/%d/%Y %I:%M %p" : "%b %d, %Y %I:%M %p"
    datetime.in_time_zone(TIMEZONE).strftime(format)
  end

  def format_degrees(degrees)
    return "N/A" unless degrees
    "#{degrees.round(1)}°"
  end
end
