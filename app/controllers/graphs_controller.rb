class GraphsController < ApplicationController
  def index
    latest_report = Report.ordered.first

    if latest_report
      redirect_to graph_path(latest_report.year, latest_report.month_name.downcase)
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

    @month_label = Date::MONTHNAMES[@current_month]
    @temperature_chart = build_temperature_chart(@current_year, @current_month, @current_day)
    @rain_chart = build_rain_chart(@current_year, @current_month, @current_day)
    @wind_chart = build_wind_chart(@current_year, @current_month, @current_day)
  end

  private

  def build_temperature_chart(year, month, day = nil)
    entries = entries_for(year, month, day)
    return nil if entries.blank?

    labels = entries.map { |e| entry_label(e) }
    highs = entries.map { |e| e.high_temp ? c_to_f(e.high_temp) : nil }
    lows = entries.map { |e| e.low_temp ? c_to_f(e.low_temp) : nil }
    means = entries.map { |e| e.mean_temp ? c_to_f(e.mean_temp) : nil }

    {
      type: "line",
      data: {
        labels: labels,
        datasets: [
          {
            label: "High",
            data: highs.map { |v| v&.round(1) },
            color: "var(--chart-2)",
            borderWidth: 2,
            tension: 0.3
          },
          {
            label: "Low",
            data: lows.map { |v| v&.round(1) },
            color: "var(--chart-1)",
            borderWidth: 2,
            tension: 0.3,
            fillTarget: 0
          },
          {
            label: "Mean",
            data: means.map { |v| v&.round(1) },
            color: "var(--chart-3)",
            borderWidth: 2,
            dashed: true,
            tension: 0.3
          }
        ]
      },
      options: {
        yUnit: "°F",
        yLabel: "Temperature (°F)",
        decimals: 1
      }
    }
  end

  def build_rain_chart(year, month, day = nil)
    entries = entries_for(year, month, day)
    return nil if entries.blank? || entries.none? { |e| e.rain.present? }

    labels = entries.map { |e| entry_label(e) }
    rain = entries.map { |e| e.rain ? (e.rain / 25.4).round(3) : 0 }

    {
      type: "bar",
      data: {
        labels: labels,
        datasets: [
          {
            label: "Rain",
            data: rain,
            color: "var(--chart-6)",
            fill: true
          }
        ]
      },
      options: {
        yUnit: " in",
        yLabel: "Rainfall (in)",
        decimals: 2,
        hideLegend: true
      }
    }
  end

  def build_wind_chart(year, month, day = nil)
    entries = entries_for(year, month, day)
    return nil if entries.blank? || entries.none? { |e| e.avg_wind_speed.present? || e.high_wind_speed.present? }

    labels = entries.map { |e| entry_label(e) }
    avg = entries.map { |e| e.avg_wind_speed ? (e.avg_wind_speed * 2.23694).round(1) : nil }
    high = entries.map { |e| e.high_wind_speed ? (e.high_wind_speed * 2.23694).round(1) : nil }

    {
      type: "line",
      data: {
        labels: labels,
        datasets: [
          {
            label: "Peak",
            data: high,
            color: "var(--chart-2)",
            tension: 0.25
          },
          {
            label: "Average",
            data: avg,
            color: "var(--chart-3)",
            tension: 0.25
          }
        ]
      },
      options: {
        yUnit: " mph",
        yLabel: "Wind speed (mph)",
        decimals: 1
      }
    }
  end

  def entries_for(year, month, day)
    report = Report.includes(:entries).find_by(year: year, month: month)
    return [] unless report

    scope = day ? report.entries.hourly.where(day: day) : report.entries.daily
    scope.ordered.with_data.to_a
  end

  def entry_label(entry)
    entry.hourly? ? format("%02d:00", entry.hour) : entry.day.to_s
  end

  def c_to_f(celsius)
    (celsius * 9.0 / 5.0) + 32
  end

  def render_not_found(message)
    respond_to do |format|
      format.html { render plain: message, status: :not_found }
      format.json { render json: { error: message }, status: :not_found }
    end
  end
end
