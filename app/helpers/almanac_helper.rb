module AlmanacHelper
  def format_time(time)
    return "N/A" unless time
    time.in_time_zone("America/Los_Angeles").strftime("%I:%M %p")
  end

  def format_datetime(datetime)
    return "N/A" unless datetime
    datetime.in_time_zone("America/Los_Angeles").strftime("%m/%d/%Y %I:%M %p")
  end

  def format_degrees(degrees)
    return "N/A" unless degrees
    "#{degrees.round(1)}°"
  end
end
