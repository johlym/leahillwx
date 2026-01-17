class GraphsController < ApplicationController
  def index
    latest_report = Report.ordered.first

    if latest_report
      @current_year = latest_report.year
      @current_month = latest_report.month
      @current_day = nil
      load_temperature_data(@current_year, @current_month, @current_day)
    else
      @message = "No data available yet. Graphs will be generated as weather data is collected."
    end
  end

  def available
    reports_data = Report.ordered.group_by(&:year)

    result = reports_data.transform_values do |reports|
      reports.group_by { |r| r.month_name.downcase }.transform_values do |month_reports|
        month_reports.first.entries.daily.pluck(:day).uniq.sort.map { |d| { day: d } }
      end
    end

    render json: result
  end

  def show
    @current_year = params[:year].to_i
    month_name = params[:month_name]
    @current_month = Date::MONTHNAMES.index(month_name.capitalize)
    @current_day = params[:day]&.to_i

    unless @current_month
      render_not_found("Invalid month name: #{month_name}")
      return
    end

    report = Report.find_by(year: @current_year, month: @current_month)
    unless report
      render_not_found("No data available for #{month_name.capitalize} #{@current_year}")
      return
    end

    load_temperature_data(@current_year, @current_month, @current_day)
  end

  private

  def load_temperature_data(year, month, day = nil)
    report = Report.includes(:entries).find_by(year: year, month: month)
    return unless report

    entries = day ? report.entries.hourly.where(day: day).ordered : report.entries.daily.ordered

    @temperature_data = entries.with_data.map do |entry|
      {
        date: entry.hourly? ? format("%02d:00", entry.hour) : entry.day.to_s,
        high: entry.high_temp ? celsius_to_fahrenheit(entry.high_temp).round(2) : nil,
        low: entry.low_temp ? celsius_to_fahrenheit(entry.low_temp).round(2) : nil,
        mean: entry.mean_temp ? celsius_to_fahrenheit(entry.mean_temp).round(2) : nil
      }
    end.compact
  end

  def celsius_to_fahrenheit(celsius)
    (celsius * 9.0 / 5.0) + 32
  end

  def render_not_found(message)
    respond_to do |format|
      format.html { render plain: message, status: :not_found }
      format.json { render json: { error: message }, status: :not_found }
    end
  end
end
