class RecordsController < ApplicationController
  def index
    @available_years = Record.where(scope: "yearly").order(year: :desc).pluck(:year)
    @available_report_months_by_year = Report.available_years_and_months
    @all_time_record = Record.all_time_record

    if params[:month_name].present? && params[:year].present?
      pivot_to_month(params[:year].to_i, params[:month_name])
    elsif params[:year].present?
      pivot_to_year(params[:year].to_i)
    else
      pivot_to_all_time
    end

    @yearly_records = Record.where(scope: "yearly").order(year: :asc).to_a
  end

  private

  def pivot_to_all_time
    @pivot = :all_time
    @selected_year = nil
    @selected_month = nil
    @selected_year_record = nil
    @heatmap_year = most_recent_year_with_data
    @heatmap_days = @heatmap_year ? load_heatmap_days(@heatmap_year) : []
  end

  def pivot_to_year(year)
    @pivot = :year
    @selected_year = year
    @selected_month = nil
    @selected_year_record = Record.for_year(year).first
    @heatmap_year = year
    @heatmap_days = load_heatmap_days(year)
  end

  def pivot_to_month(year, month_name)
    month = Date::MONTHNAMES.index(month_name.to_s.capitalize)
    unless month
      pivot_to_year(year)
      return
    end

    @pivot = :month
    @selected_year = year
    @selected_month = month
    @month_name = Date::MONTHNAMES[month]
    @report = Report.includes(:entries).find_by(year: year, month: month)
    @prior_report = Report.includes(:entries).find_by(year: year - 1, month: month)

    # Heatmap follows the pivoted year so the visual context stays put.
    @heatmap_year = year
    @heatmap_days = load_heatmap_days(year)
  end

  def most_recent_year_with_data
    Report.where.not(id: nil).maximum(:year)
  end

  def load_heatmap_days(year)
    ReportEntry
      .joins(:report)
      .where(hour: nil)
      .where(reports: { year: year })
      .where.not(mean_temp: nil)
      .order("reports.month, day")
      .pluck(Arel.sql("reports.month"), :day, :high_temp, :low_temp, :mean_temp, :partial_period)
      .map { |month, day, hi_c, lo_c, mean_c, partial|
        {
          month: month,
          day: day,
          high_f: hi_c ? (hi_c * 9.0 / 5.0 + 32.0) : nil,
          low_f: lo_c ? (lo_c * 9.0 / 5.0 + 32.0) : nil,
          mean_f: mean_c ? (mean_c * 9.0 / 5.0 + 32.0) : nil,
          partial: !!partial
        }
      }
  end
end
