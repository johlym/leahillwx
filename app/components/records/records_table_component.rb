# frozen_string_literal: true

class Records::RecordsTableComponent < ViewComponent::Base
  def initialize(selected_year_record:, current_year_record:, all_time_record:, selected_year:, current_year:)
    @selected_year_record = selected_year_record
    @current_year_record = current_year_record
    @all_time_record = all_time_record
    @selected_year = selected_year
    @current_year = current_year
  end

  def show_three_columns?
    @selected_year != @current_year
  end

  private

  def format_temp(celsius)
    return "N/A" unless celsius
    "#{(celsius * 9/5 + 32).round(1)}°F"
  end

  def format_datetime(datetime)
    return "N/A" unless datetime
    datetime.in_time_zone("America/Los_Angeles").strftime("%b %d, %Y %I:%M %p")
  end

  def format_date(date)
    return "N/A" unless date
    date.strftime("%b %d, %Y")
  end

  def format_speed(mps)
    return "N/A" unless mps
    "#{(mps * 2.23694).round(1)} mph"
  end

  def format_rain(mm)
    return "N/A" unless mm
    "#{(mm / 25.4).round(2)} in"
  end

  def format_pressure(hpa)
    return "N/A" unless hpa
    "#{hpa.round(2)} hPa"
  end

  def format_solar(wm2)
    return "N/A" unless wm2
    "#{wm2.round(1)} W/m²"
  end

  def format_month(month_num, year)
    return "N/A" unless month_num && year
    "#{Date::MONTHNAMES[month_num]} #{year}"
  end

  def format_wind_run(miles)
    return "N/A" unless miles
    "#{miles.round(1)} miles"
  end

  def format_hours(hours)
    return "N/A" unless hours
    "#{hours} hours"
  end

  def format_days(days)
    return "N/A" unless days
    "#{days} days"
  end

  def format_humidity(humidity)
    return "N/A" unless humidity
    "#{humidity}%"
  end
end
