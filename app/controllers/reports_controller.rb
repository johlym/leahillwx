class ReportsController < ApplicationController
  def index
    latest_report = Report.ordered.first

    if latest_report
      redirect_to report_path(latest_report.year, latest_report.month_name.downcase)
    else
      @message = "No reports available yet. Reports will be generated as weather data is collected."
    end
  end

  def available
    reports = Report.ordered.includes(:entries)

    result = reports.group_by(&:year).transform_values do |year_reports|
      year_reports.group_by { |r| r.month_name.downcase }.transform_values do |month_reports|
        month_reports.first.entries.map(&:day).uniq.sort.map { |d| { day: d } }
      end
    end

    render json: result
  end

  def show
    @start_time = Time.current

    year = params[:year].to_i
    month_name = params[:month_name]
    month_num = Date::MONTHNAMES.index(month_name.capitalize)

    unless month_num
      render_not_found("Invalid month name: #{month_name}")
      return
    end

    @report = Report.includes(:entries).find_by(year: year, month: month_num)

    unless @report
      render_not_found("Report not found for #{month_name.capitalize} #{year}")
      return
    end

    @generation_time = (Time.current - @start_time).round(2)

    respond_to do |format|
      format.html # renders show.html.erb
      format.text do
        render plain: render_to_string(
          partial: "reports/show_text",
          locals: { report: @report, generation_time: @generation_time }
        )
      end
    end
  end

  def show_day
    @start_time = Time.current

    year = params[:year].to_i
    month_name = params[:month_name]
    @day = params[:day].to_i
    month_num = Date::MONTHNAMES.index(month_name.capitalize)

    unless month_num
      render_not_found("Invalid month name: #{month_name}")
      return
    end

    unless @day.between?(1, 31)
      render_not_found("Invalid day: #{@day}")
      return
    end

    @report = Report.includes(:entries).find_by(year: year, month: month_num)

    unless @report
      render_not_found("Report not found for #{month_name.capitalize} #{year}")
      return
    end

    # Get the daily entry for summary statistics
    @daily_entry = @report.entries.daily.find_by(day: @day)

    @generation_time = (Time.current - @start_time).round(2)

    respond_to do |format|
      format.html # renders show_day.html.erb
      format.text do
        render plain: render_to_string(
          partial: "reports/show_day_text",
          locals: {
            report: @report,
            day: @day,
            daily_entry: @daily_entry,
            generation_time: @generation_time
          }
        )
      end
    end
  end

  private

  def render_not_found(message)
    respond_to do |format|
      format.html { render plain: message, status: :not_found }
      format.text { render plain: message, status: :not_found }
      format.json { render json: { error: message }, status: :not_found }
    end
  end
end
