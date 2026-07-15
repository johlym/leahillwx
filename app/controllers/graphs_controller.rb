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
    reports = Report.ordered.includes(:entries)

    result = reports.group_by(&:year).transform_values do |year_reports|
      year_reports.group_by { |r| r.month_name.downcase }.transform_values do |month_reports|
        month_reports.first.entries.select { |e| e.hour.nil? }.map(&:day).uniq.sort.map { |d| { day: d } }
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
    charts = Graphs::ChartBuilder.new(year: @current_year, month: @current_month, day: @current_day)
    @temperature_chart = charts.temperature_chart
    @rain_chart = charts.rain_chart
    @wind_chart = charts.wind_chart
  end

  private

  def render_not_found(message)
    respond_to do |format|
      format.html { render plain: message, status: :not_found }
      format.json { render json: { error: message }, status: :not_found }
    end
  end
end
